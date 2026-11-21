"""Prompt prototyping for the Eudemonia synthesis turns against a local llama-server."""
import json, sys, time, urllib.request

URL = 'http://localhost:8089'
FOLDERS = {
    'Work': 'the job or the projects being built: meetings, colleagues, clients, budgets, code, product and design decisions, deadlines',
    'Ideas': 'new possibilities and what-ifs: features that could exist, concepts, observations to explore later',
    'Todos': 'personal errands and reminders outside of work: shopping, appointments, bookings, calls, chores',
    'Journal': 'feelings, mood, health, family moments, reflections on the day',
    'Uncategorized': 'only when the thought fits none of the above',
}


def complete(prompt, grammar=None, n_predict=512):
    system, user = prompt
    body = {'messages': [{'role': 'system', 'content': system}, {'role': 'user', 'content': user}],
            'temperature': 0, 'max_tokens': n_predict, 'cache_prompt': False}
    if grammar:
        body['grammar'] = grammar
    req = urllib.request.Request(URL + '/v1/chat/completions', json.dumps(body).encode(), {'Content-Type': 'application/json'})
    t = time.time()
    r = json.load(urllib.request.urlopen(req))
    u = r['usage']
    return r['choices'][0]['message']['content'], u['prompt_tokens'], u['completion_tokens'], time.time() - t


def chatml(system, user):
    return (system, user)


import os
SUBJECT = os.environ.get('FOLDERSET') == 'subject'
if SUBJECT:
    NAMES = ['Work', 'Personal', 'Journal', 'Uncategorized']
    RULES = ('Folders (each is a subject area of the speaker\'s life):\n'
             '- Work: the job and the app or software being built; colleagues, clients, meetings, budgets, invoices, '
             'design, features, product plans, work travel.\n'
             '- Personal: running the speaker\'s own life; shopping, errands, home, appointments, family plans, '
             'places and things to remember.\n'
             '- Journal: how the speaker feels; mood, sleep, health, exercise, reflections on the day.\n'
             '- Uncategorized: only when the text fits none of these or makes no sense.\n\n'
             'Choose by what the thought is about, not by whether it is a task, a reminder or an idea.\n')
    EXAMPLE = ('Example:\nThoughts:\n1. Ask Dev to move the release to Monday.\n2. Buy stamps and post the letter.\n'
               '3. Also the login button should be bigger.\n4. Slept badly, feeling low today.\n'
               'Answer:\n1: Work\n2: Personal\n3: Work\n4: Journal')
else:
    NAMES = ['Work', 'Journal', 'Todos', 'Ideas', 'Uncategorized']
    RULES = ('Decide in this order and stop at the first that fits:\n'
             '1. Work - anything about the job, the app or software being built, colleagues, clients, meetings, '
             'budgets, invoices, design, product plans. A task for work is still Work.\n'
             '2. Journal - feelings, mood, health, family, how the day went.\n'
             '3. Todos - personal errands and reminders: shopping, appointments, bookings, chores, things to remember.\n'
             '4. Ideas - a new possibility or what-if that is not about current work.\n'
             '5. Uncategorized - none of the above, or the text makes no sense.\n')
    EXAMPLE = ('Example:\nThoughts:\n1. Ask Dev to move the release to Monday.\n2. Buy stamps and post the letter.\n'
               '3. Also the login button should be bigger.\n4. Slept badly, feeling low today.\n'
               'Answer:\n1: Work\n2: Todos\n3: Work\n4: Journal')


def organise_prompt(thoughts, open_sessions=()):
    system = ('You sort the spoken thoughts of one person into folders. The thoughts were transcribed by '
              'speech recognition, so some words may be wrong.\n\n' + RULES +
              '\nA short or unclear thought usually continues the subject of the thoughts next to it.\n\n' + EXAMPLE)
    user = ''
    if open_sessions:
        user += 'Notes already in progress:\n' + '\n'.join(f'[{f}] {n}' for f, n in open_sessions) + '\n\n'
    user += 'Thoughts:\n' + '\n'.join(f'{i + 1}. {t}' for i, t in enumerate(thoughts)) + '\nAnswer:'
    return chatml(system, user)


def organise_grammar(n):
    lines = ' '.join(f'"{i + 1}: " folder "\\n"' for i in range(n))
    return 'root ::= ' + lines + '\nfolder ::= ' + ' | '.join(f'"{f}"' for f in NAMES)


NO_GRAMMAR = os.environ.get('NOGRAMMAR') == '1'
INVALID = [0]


def organise(thoughts, open_sessions=()):
    """Returns one folder per thought. Without a grammar the reply is validated the way the app must do it."""
    grammar = None if NO_GRAMMAR else organise_grammar(len(thoughts))
    out, pin, pout, dt = complete(organise_prompt(thoughts, open_sessions), grammar, 8 * len(thoughts) + 8)
    labels = []
    for i, line in enumerate(out.strip().split('\n')[:len(thoughts)]):
        num, _, folder = line.partition(':')
        labels.append(folder.strip() if num.strip() == str(i + 1) and folder.strip() in NAMES else None)
    labels += [None] * (len(thoughts) - len(labels))
    if None in labels or len(out.strip().split('\n')) != len(thoughts):
        INVALID[0] += 1
        if '-v' in sys.argv: print('INVALID REPLY:', repr(out))
    return labels, pin, pout, dt


WRITE_SYSTEM = (
    'You turn spoken thoughts into one clear written note. The thoughts were dictated by one person, in order, and '
    'transcribed by speech recognition.\n\n'
    'Rules:\n'
    '- Keep every fact: names, numbers, dates, times, places, items in lists, reasons.\n'
    '- When the speaker corrects themselves, keep only the corrected version.\n'
    '- Remove filler words, false starts and repetition.\n'
    '- Add nothing that was not said. Do not guess missing details, do not give advice, do not add a title or a closing remark.\n'
    '- Write in the first person, as the speaker, in plain sentences. Use a short list only when the speaker listed items.\n'
    '- All thoughts matter equally; do not give the last one more weight.\n'
    '- Output only the note. Begin with its first sentence, with no introduction.')


def write_prompt(thoughts):
    user = 'Thoughts:\n' + '\n'.join(f'{i + 1}. {t}' for i, t in enumerate(thoughts)) + '\n\nWrite the note.'
    return chatml(WRITE_SYSTEM, user)


def write(thoughts):
    words = sum(len(t.split()) for t in thoughts)
    return complete(write_prompt(thoughts), None, int(words * 1.6) + 96)


if __name__ == '__main__':
    T = json.load(open(sys.argv[1]))
    mode = sys.argv[2]
    if mode == 'organise':
        ids = sys.argv[3].split(',') if len(sys.argv) > 3 else [t['id'] for t in T]
        sel = [t for t in T if t['id'] in ids]
        labels, pin, pout, dt = organise([t['text'] for t in sel])
        ok = tot = 0
        for t, l in zip(sel, labels):
            mark = ''
            if t['expected']:
                tot += 1; ok += l == t['expected']; mark = 'OK' if l == t['expected'] else f'EXPECTED {t["expected"]}'
            print(f'{t["id"]} {l:14s} {mark:18s} {t["text"][:70]}')
        print(f'labelled {ok}/{tot} | in {pin} tok, out {pout} tok, {dt:.1f}s')
    elif mode == 'write':
        ids = sys.argv[3].split(',')
        sel = [t['text'] for t in T if t['id'] in ids]
        out, pin, pout, dt = write(sel)
        print(out.strip()); print(f'--- in {pin} tok, out {pout} tok, {dt:.1f}s, input words {sum(len(t.split()) for t in sel)}, output words {len(out.split())}')


ACCEPT = {'r01': 'Todos', 'r02': 'Work Ideas', 'r03': 'Work', 'r04': 'Journal', 'r05': 'Uncategorized', 'r06': 'Work',
          'r07': 'Todos', 'r08': 'Work', 'r09': 'Work Journal', 'r10': 'Work', 'r11': 'Work Ideas', 'r12': 'Work',
          'r13': 'Journal', 'r14': 'Work Ideas', 'r15': 'Work', 'r16': 'Todos', 'r17': 'Ideas Journal Work',
          'r18': 'Work Todos', 'r19': 'Todos Journal Uncategorized', 'r21': 'Work Uncategorized', 'r22': 'Work Uncategorized'}
CONTEXT = [
    ((), ['I think the settings page of the app needs a search bar.', 'And make the font bigger there.',
          'Pick up the parcel from the post office.'], ['Work', 'Work', 'Todos']),
    ((), ['Feeling anxious about tomorrow.', 'Did not sleep much either.', 'Email the client the revised quote.'],
     ['Journal', 'Journal', 'Work']),
    ((('Work', 'Redesign of onboarding: cut it to three steps.'),), ['Also remove the second screen entirely.',
                                                                     'Call mom on Sunday.'], ['Work', 'Todos']),
    ((), ['Buy eggs and bread.', 'Oh and candles for the cake.', 'The sprint demo is on Friday at two.',
          'Need slides for that.'], ['Todos', 'Todos', 'Work', 'Work']),
]


if SUBJECT:
    ACCEPT = {'r01': 'Personal', 'r02': 'Work', 'r03': 'Work', 'r04': 'Journal', 'r05': 'Uncategorized', 'r06': 'Work',
              'r07': 'Personal', 'r08': 'Work', 'r09': 'Work Journal', 'r10': 'Work', 'r11': 'Work', 'r12': 'Work',
              'r13': 'Journal Personal', 'r14': 'Work', 'r15': 'Work', 'r16': 'Personal', 'r17': 'Work Journal Personal',
              'r18': 'Work Personal', 'r19': 'Personal', 'r21': 'Work Uncategorized', 'r22': 'Work Uncategorized'}
    CONTEXT = [(s, t, [('Personal' if x == 'Todos' else x) for x in e]) for s, t, e in CONTEXT]


def evaluate(T):
    by = {t['id']: t['text'] for t in T}
    ids = list(ACCEPT)
    res = {}
    for name, size in (('all21', 21), ('batch5', 5), ('batch3', 3)):
        ok = 0; t0 = time.time()
        for i in range(0, len(ids), size):
            chunk = ids[i:i + size]
            labels = organise([by[c] for c in chunk])[0]
            ok += sum(l in ACCEPT[c].split() for c, l in zip(chunk, labels))
        res[name] = f'{ok}/21 ({time.time() - t0:.1f}s)'
    ok = tot = 0
    for sessions, thoughts, exp in CONTEXT:
        labels = organise(thoughts, sessions)[0]
        ok += sum(a == b for a, b in zip(labels, exp)); tot += len(exp)
    res['context'] = f'{ok}/{tot}'
    res['invalid_replies'] = INVALID[0]
    print(res)


if __name__ == '__main__' and sys.argv[2] == 'eval':
    evaluate(json.load(open(sys.argv[1])))


UPDATE_SYSTEM = WRITE_SYSTEM.replace(
    'You turn spoken thoughts into one clear written note.',
    'You update a written note with new spoken thoughts from the same person.').replace(
    '- All thoughts matter equally; do not give the last one more weight.',
    '- Keep everything in the current note exactly as it is unless a new thought changes or corrects it.\n'
    '- Put each new thought where it belongs in the note; do not let it take over the note.')


def update(note, thoughts):
    user = ('Current note:\n' + note + '\n\nNew thoughts:\n' + '\n'.join(f'{i + 1}. {t}' for i, t in enumerate(thoughts)) +
            '\n\nWrite the updated note.')
    words = len(note.split()) + sum(len(t.split()) for t in thoughts)
    return complete((UPDATE_SYSTEM, user), None, int(words * 1.6) + 96)


UPDATES = [
    ('First, pick up the dry cleaning before noon on Saturday. Second, order a birthday cake for Anjali chocolate for about twelve people. Third, renew the car insurance. It expires on the 30th. And don\'t forget to water the plants.',
     ['Actually make the cake vanilla not chocolate, and it is for fifteen people now.', 'Um also get candles.']),
    ('The onboarding screen feels too long. We should cut it down to three steps.',
     ['The second step can just be merged into the first one.', 'And uh the skip button should be at the top right.']),
]

if __name__ == '__main__' and sys.argv[2] == 'update':
    for note, th in UPDATES:
        out, pin, pout, dt = update(note, th)
        print(out.strip()); print(f'--- in {pin}, out {pout}\n')
