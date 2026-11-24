import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'llama_bindings.g.dart';

/// The synchronous llama.cpp operations the generation loop needs: one sequence (0), on the CPU.
/// Every call blocks the calling isolate; run it on a worker isolate.
abstract class LlamaBackend {
  /// Tokens the memory can hold (prompt and output together).
  int get contextSize;

  /// Most tokens one [decode] call accepts; the prompt chunk size.
  int get batchSize;

  /// Tokens of [text], with the model's start tokens added and control tokens such as
  /// `<|im_start|>` read as single tokens.
  List<int> tokenize(String text);

  /// Removes every token at [position] or later from the memory.
  void truncateMemory(int position);

  /// Decodes [tokens] at positions `start, start + 1, …`. Logits are computed for the last token
  /// only when [logitsForLast]; [sample] reads them. Throws when llama.cpp reports a failure.
  void decode(List<int> tokens, int start, {required bool logitsForLast});

  /// Replaces the sampler with a fresh chain: the GBNF [grammar] (start symbol `root`) when
  /// given, then greedy. Throws [FormatException] when the grammar does not parse.
  void startSampler({String? grammar});

  /// Picks the next token from the last logits; the sampler (and its grammar) accepts it.
  int sample();

  /// True for tokens that end the reply (end of turn, end of text).
  bool isEndOfGeneration(int token);

  /// The UTF-8 bytes [token] adds to the reply text; control tokens add none. A character can
  /// span two tokens, so decode the bytes of a whole reply at once.
  Uint8List tokenBytes(int token);

  /// Threads used for decoding prompt chunks ([reading]) and single tokens ([writing]).
  void setThreads({required int reading, required int writing});

  /// Frees the model, the memory and everything else the backend allocated.
  void dispose();
}

/// [LlamaBackend] over the llama.cpp shared libraries. CPU only, flash attention on, one batch
/// of [batchSize] tokens allocated once, one persistent thread pool of [threadPoolSize] threads
/// for reading and writing. `llama_backend_free` is never called: it is process-wide and the
/// worker isolate may load the model again.
class NativeLlamaBackend implements LlamaBackend {
  /// The Android library name; the ggml libraries are expected next to it.
  static const String defaultLibraryPath = 'libllama.so';

  /// Size of the thread pool; [setThreads] uses at most this many threads.
  static const int threadPoolSize = 8;

  static const int _pieceBufferBytes = 256;

  final LlamaBindings _llama;
  final Pointer<llama_model> _model;
  final Pointer<llama_context> _context;
  final Pointer<llama_vocab> _vocab;
  final Pointer<llama_memory_i> _memory;
  final Pointer<ggml_threadpool> _threadPool;
  final llama_batch _batch;
  final Pointer<Uint8> _pieceBuffer;
  Pointer<llama_sampler> _sampler = nullptr;
  bool _disposed = false;

  @override
  final int contextSize;
  @override
  final int batchSize;

  NativeLlamaBackend._(this._llama, this._model, this._context, this._threadPool, this._batch,
      {required this.contextSize, required this.batchSize})
      : _vocab = _llama.llama_model_get_vocab(_model),
        _memory = _llama.llama_get_memory(_context),
        _pieceBuffer = calloc<Uint8>(_pieceBufferBytes);

  /// Loads [modelPath] with a context of [contextSize] tokens decoded in chunks of [batchSize].
  /// Throws when a library, the model or the context cannot be loaded; nothing stays allocated.
  factory NativeLlamaBackend.load(
    String modelPath, {
    required int contextSize,
    required int batchSize,
    String libraryPath = defaultLibraryPath,
  }) {
    if (contextSize <= 0 || batchSize <= 0 || batchSize > contextSize) {
      throw ArgumentError('Invalid sizes: context $contextSize, batch $batchSize.');
    }
    final llama = _openLibraries(libraryPath);
    llama.llama_backend_init();

    // No GPU device at all: the bundled library is CPU only and rejects a main GPU.
    // Direct I/O, not the default memory map: this llama.cpp repacks the quantised weights into
    // its own buffers at load, so a mapped file is held a second time (Qwen3-4B on the Pixel 7a:
    // peak 4.25 GB mapped against 2.81 GB read directly) and reading through the page cache
    // would push other apps' pages out. llama.cpp falls back to plain reads where direct I/O
    // is not available.
    final modelParams = llama.llama_model_default_params()
      ..load_mode = llama_load_mode.LLAMA_LOAD_MODE_DIRECT_IO
      ..n_gpu_layers = 0
      ..split_mode = llama_split_mode.LLAMA_SPLIT_MODE_NONE
      ..main_gpu = -1;
    final path = modelPath.toNativeUtf8();
    final Pointer<llama_model> model;
    try {
      model = llama.llama_model_load_from_file(path.cast(), modelParams);
    } finally {
      calloc.free(path);
    }
    if (model == nullptr) throw Exception('llama.cpp could not load the model at $modelPath.');

    final contextParams = llama.llama_context_default_params()
      ..n_ctx = contextSize
      ..n_batch = batchSize
      ..n_ubatch = batchSize
      ..n_seq_max = 1
      ..n_threads = 4
      ..n_threads_batch = 4
      ..flash_attn_type = llama_flash_attn_type.LLAMA_FLASH_ATTN_TYPE_ENABLED
      ..no_perf = true;
    final context = llama.llama_init_from_model(model, contextParams);
    if (context == nullptr) {
      llama.llama_model_free(model);
      throw Exception('llama.cpp could not create a context of $contextSize tokens.');
    }

    final poolParams = calloc<ggml_threadpool_params>();
    final Pointer<ggml_threadpool> pool;
    try {
      poolParams.ref = llama.ggml_threadpool_params_default(threadPoolSize);
      pool = llama.ggml_threadpool_new(poolParams);
    } finally {
      calloc.free(poolParams);
    }
    if (pool == nullptr) {
      llama.llama_free(context);
      llama.llama_model_free(model);
      throw Exception('ggml could not create a thread pool of $threadPoolSize threads.');
    }
    llama.llama_attach_threadpool(context, pool, pool);

    final batch = llama.llama_batch_init(batchSize, 0, 1);
    for (var i = 0; i < batchSize; i++) {
      batch.n_seq_id[i] = 1;
      batch.seq_id[i][0] = 0;
    }
    return NativeLlamaBackend._(llama, model, context, pool, batch,
        contextSize: llama.llama_n_ctx(context), batchSize: batchSize);
  }

  /// Opens libllama and, when present next to it, libggml-base and libggml-cpu: the thread pool
  /// functions are defined there, not in libllama.
  static LlamaBindings _openLibraries(String libraryPath) {
    final llama = DynamicLibrary.open(libraryPath);
    final slash = libraryPath.lastIndexOf('/');
    final dir = libraryPath.substring(0, slash + 1);
    final name = libraryPath.substring(slash + 1);
    final dot = name.indexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot);
    final libraries = [
      llama,
      for (final ggml in const ['libggml-base', 'libggml-cpu']) ?_tryOpen('$dir$ggml$extension'),
    ];
    return LlamaBindings.fromLookup(<T extends NativeType>(String symbol) {
      for (final library in libraries) {
        if (library.providesSymbol(symbol)) return library.lookup<T>(symbol);
      }
      throw ArgumentError('$symbol is not in $libraryPath or the ggml libraries next to it.');
    });
  }

  static DynamicLibrary? _tryOpen(String path) {
    try {
      return DynamicLibrary.open(path);
    } catch (_) {
      return null;
    }
  }

  void _checkOpen() {
    if (_disposed) throw StateError('NativeLlamaBackend used after dispose.');
  }

  @override
  List<int> tokenize(String text) {
    _checkOpen();
    final bytes = utf8.encode(text);
    final textPointer = calloc<Uint8>(bytes.length + 1);
    try {
      textPointer.asTypedList(bytes.length).setAll(0, bytes);
      // A token covers at least one byte; the margin holds the start and end tokens.
      var capacity = bytes.length + 8;
      for (var attempt = 0; attempt < 2; attempt++) {
        final tokens = calloc<Int32>(capacity);
        try {
          final n = _llama.llama_tokenize(_vocab, textPointer.cast(), bytes.length, tokens, capacity, true, true);
          if (n >= 0) return List<int>.of(tokens.asTypedList(n));
          if (n == -0x80000000) break;
          capacity = -n;
        } finally {
          calloc.free(tokens);
        }
      }
      throw StateError('llama.cpp could not tokenize a prompt of ${bytes.length} bytes.');
    } finally {
      calloc.free(textPointer);
    }
  }

  @override
  void truncateMemory(int position) {
    _checkOpen();
    if (!_llama.llama_memory_seq_rm(_memory, 0, position, -1)) {
      throw StateError('llama.cpp could not remove the memory from position $position.');
    }
  }

  @override
  void decode(List<int> tokens, int start, {required bool logitsForLast}) {
    _checkOpen();
    final n = tokens.length;
    if (n == 0 || n > batchSize) throw ArgumentError('A chunk holds 1 to $batchSize tokens, not $n.');
    for (var i = 0; i < n; i++) {
      _batch.token[i] = tokens[i];
      _batch.pos[i] = start + i;
      _batch.logits[i] = 0;
    }
    if (logitsForLast) _batch.logits[n - 1] = 1;
    _batch.n_tokens = n;
    final result = _llama.llama_decode(_context, _batch);
    if (result != 0) throw StateError('llama_decode returned $result for $n tokens at position $start.');
  }

  @override
  void startSampler({String? grammar}) {
    _checkOpen();
    _freeSampler();
    final chain = _llama.llama_sampler_chain_init(_llama.llama_sampler_chain_default_params()..no_perf = true);
    if (grammar != null) {
      final text = grammar.toNativeUtf8();
      final root = 'root'.toNativeUtf8();
      final Pointer<llama_sampler> constraint;
      try {
        constraint = _llama.llama_sampler_init_grammar(_vocab, text.cast(), root.cast());
      } finally {
        calloc.free(text);
        calloc.free(root);
      }
      if (constraint == nullptr) {
        _llama.llama_sampler_free(chain);
        throw const FormatException('llama.cpp could not parse the grammar.');
      }
      _llama.llama_sampler_chain_add(chain, constraint);
    }
    _llama.llama_sampler_chain_add(chain, _llama.llama_sampler_init_greedy());
    _sampler = chain;
  }

  @override
  int sample() {
    _checkOpen();
    if (_sampler == nullptr) throw StateError('NativeLlamaBackend.sample called before startSampler.');
    return _llama.llama_sampler_sample(_sampler, _context, -1);
  }

  @override
  bool isEndOfGeneration(int token) {
    _checkOpen();
    return _llama.llama_vocab_is_eog(_vocab, token);
  }

  @override
  Uint8List tokenBytes(int token) {
    _checkOpen();
    final n = _llama.llama_token_to_piece(_vocab, token, _pieceBuffer.cast(), _pieceBufferBytes, 0, false);
    if (n >= 0) return Uint8List.fromList(_pieceBuffer.asTypedList(n));
    final buffer = calloc<Uint8>(-n);
    try {
      final m = _llama.llama_token_to_piece(_vocab, token, buffer.cast(), -n, 0, false);
      if (m < 0) throw StateError('llama.cpp could not render token $token.');
      return Uint8List.fromList(buffer.asTypedList(m));
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  void setThreads({required int reading, required int writing}) {
    _checkOpen();
    _llama.llama_set_n_threads(_context, writing.clamp(1, threadPoolSize), reading.clamp(1, threadPoolSize));
  }

  void _freeSampler() {
    if (_sampler != nullptr) _llama.llama_sampler_free(_sampler);
    _sampler = nullptr;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _freeSampler();
    _llama.llama_batch_free(_batch);
    // The context uses the thread pool, so it goes first.
    _llama.llama_free(_context);
    _llama.ggml_threadpool_free(_threadPool);
    _llama.llama_model_free(_model);
    calloc.free(_pieceBuffer);
  }
}
