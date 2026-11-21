// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'synthesis_session_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetSynthesisSessionRecordCollection on Isar {
  IsarCollection<SynthesisSessionRecord> get synthesisSessionRecords =>
      this.collection();
}

const SynthesisSessionRecordSchema = CollectionSchema(
  name: r'SynthesisSessionRecord',
  id: -8318902129018200335,
  properties: {
    r'appliedStyleId': PropertySchema(
      id: 0,
      name: r'appliedStyleId',
      type: IsarType.string,
    ),
    r'clusterId': PropertySchema(
      id: 1,
      name: r'clusterId',
      type: IsarType.string,
    ),
    r'folder': PropertySchema(id: 2, name: r'folder', type: IsarType.string),
    r'isActionExtracted': PropertySchema(
      id: 3,
      name: r'isActionExtracted',
      type: IsarType.bool,
    ),
    r'isReprocessing': PropertySchema(
      id: 4,
      name: r'isReprocessing',
      type: IsarType.bool,
    ),
    r'isUnread': PropertySchema(id: 5, name: r'isUnread', type: IsarType.bool),
    r'originNotes': PropertySchema(
      id: 6,
      name: r'originNotes',
      type: IsarType.objectList,

      target: r'SynthesisOriginRecord',
    ),
    r'sequenceNumber': PropertySchema(
      id: 7,
      name: r'sequenceNumber',
      type: IsarType.string,
    ),
    r'sessionDurationSeconds': PropertySchema(
      id: 8,
      name: r'sessionDurationSeconds',
      type: IsarType.long,
    ),
    r'sessionEnd': PropertySchema(
      id: 9,
      name: r'sessionEnd',
      type: IsarType.dateTime,
    ),
    r'sessionStart': PropertySchema(
      id: 10,
      name: r'sessionStart',
      type: IsarType.dateTime,
    ),
    r'synthesizedContent': PropertySchema(
      id: 11,
      name: r'synthesizedContent',
      type: IsarType.string,
    ),
  },

  estimateSize: _synthesisSessionRecordEstimateSize,
  serialize: _synthesisSessionRecordSerialize,
  deserialize: _synthesisSessionRecordDeserialize,
  deserializeProp: _synthesisSessionRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'clusterId': IndexSchema(
      id: 1919966277605001711,
      name: r'clusterId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'clusterId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'SynthesisOriginRecord': SynthesisOriginRecordSchema},

  getId: _synthesisSessionRecordGetId,
  getLinks: _synthesisSessionRecordGetLinks,
  attach: _synthesisSessionRecordAttach,
  version: '3.4.1',
);

int _synthesisSessionRecordEstimateSize(
  SynthesisSessionRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.appliedStyleId.length * 3;
  bytesCount += 3 + object.clusterId.length * 3;
  bytesCount += 3 + object.folder.length * 3;
  bytesCount += 3 + object.originNotes.length * 3;
  {
    final offsets = allOffsets[SynthesisOriginRecord]!;
    for (var i = 0; i < object.originNotes.length; i++) {
      final value = object.originNotes[i];
      bytesCount += SynthesisOriginRecordSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.sequenceNumber.length * 3;
  bytesCount += 3 + object.synthesizedContent.length * 3;
  return bytesCount;
}

void _synthesisSessionRecordSerialize(
  SynthesisSessionRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.appliedStyleId);
  writer.writeString(offsets[1], object.clusterId);
  writer.writeString(offsets[2], object.folder);
  writer.writeBool(offsets[3], object.isActionExtracted);
  writer.writeBool(offsets[4], object.isReprocessing);
  writer.writeBool(offsets[5], object.isUnread);
  writer.writeObjectList<SynthesisOriginRecord>(
    offsets[6],
    allOffsets,
    SynthesisOriginRecordSchema.serialize,
    object.originNotes,
  );
  writer.writeString(offsets[7], object.sequenceNumber);
  writer.writeLong(offsets[8], object.sessionDurationSeconds);
  writer.writeDateTime(offsets[9], object.sessionEnd);
  writer.writeDateTime(offsets[10], object.sessionStart);
  writer.writeString(offsets[11], object.synthesizedContent);
}

SynthesisSessionRecord _synthesisSessionRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SynthesisSessionRecord();
  object.appliedStyleId = reader.readString(offsets[0]);
  object.clusterId = reader.readString(offsets[1]);
  object.folder = reader.readString(offsets[2]);
  object.id = id;
  object.isActionExtracted = reader.readBool(offsets[3]);
  object.isReprocessing = reader.readBool(offsets[4]);
  object.isUnread = reader.readBool(offsets[5]);
  object.originNotes =
      reader.readObjectList<SynthesisOriginRecord>(
        offsets[6],
        SynthesisOriginRecordSchema.deserialize,
        allOffsets,
        SynthesisOriginRecord(),
      ) ??
      [];
  object.sequenceNumber = reader.readString(offsets[7]);
  object.sessionDurationSeconds = reader.readLong(offsets[8]);
  object.sessionEnd = reader.readDateTime(offsets[9]);
  object.sessionStart = reader.readDateTime(offsets[10]);
  object.synthesizedContent = reader.readString(offsets[11]);
  return object;
}

P _synthesisSessionRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readObjectList<SynthesisOriginRecord>(
                offset,
                SynthesisOriginRecordSchema.deserialize,
                allOffsets,
                SynthesisOriginRecord(),
              ) ??
              [])
          as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _synthesisSessionRecordGetId(SynthesisSessionRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _synthesisSessionRecordGetLinks(
  SynthesisSessionRecord object,
) {
  return [];
}

void _synthesisSessionRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  SynthesisSessionRecord object,
) {
  object.id = id;
}

extension SynthesisSessionRecordQueryWhereSort
    on QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QWhere> {
  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SynthesisSessionRecordQueryWhere
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QWhereClause
        > {
  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  clusterIdEqualTo(String clusterId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'clusterId', value: [clusterId]),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterWhereClause
  >
  clusterIdNotEqualTo(String clusterId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clusterId',
                lower: [],
                upper: [clusterId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clusterId',
                lower: [clusterId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clusterId',
                lower: [clusterId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'clusterId',
                lower: [],
                upper: [clusterId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension SynthesisSessionRecordQueryFilter
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QFilterCondition
        > {
  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'appliedStyleId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'appliedStyleId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'appliedStyleId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'appliedStyleId', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  appliedStyleIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'appliedStyleId', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'clusterId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'clusterId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'clusterId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'clusterId', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  clusterIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'clusterId', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'folder',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'folder',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'folder',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'folder', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  folderIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'folder', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  isActionExtractedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isActionExtracted', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  isReprocessingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isReprocessing', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  isUnreadEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isUnread', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'originNotes', length, true, length, true);
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'originNotes', 0, true, 0, true);
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'originNotes', 0, false, 999999, true);
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'originNotes', 0, true, length, include);
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'originNotes', length, include, 999999, true);
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originNotes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sequenceNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sequenceNumber',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sequenceNumber',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sequenceNumber', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sequenceNumberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sequenceNumber', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionDurationSecondsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sessionDurationSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionDurationSecondsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionDurationSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionDurationSecondsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionDurationSeconds',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionDurationSecondsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionDurationSeconds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionEndEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sessionEnd', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionEndGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionEnd',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionEndLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionEnd',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionEndBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionEnd',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionStartEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sessionStart', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionStartGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionStart',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionStartLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionStart',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  sessionStartBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionStart',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'synthesizedContent',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'synthesizedContent',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'synthesizedContent',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'synthesizedContent', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  synthesizedContentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'synthesizedContent', value: ''),
      );
    });
  }
}

extension SynthesisSessionRecordQueryObject
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QFilterCondition
        > {
  QueryBuilder<
    SynthesisSessionRecord,
    SynthesisSessionRecord,
    QAfterFilterCondition
  >
  originNotesElement(FilterQuery<SynthesisOriginRecord> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'originNotes');
    });
  }
}

extension SynthesisSessionRecordQueryLinks
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QFilterCondition
        > {}

extension SynthesisSessionRecordQuerySortBy
    on QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QSortBy> {
  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByAppliedStyleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedStyleId', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByAppliedStyleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedStyleId', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByClusterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterId', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByClusterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterId', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByFolder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folder', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByFolderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folder', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsActionExtracted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActionExtracted', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsActionExtractedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActionExtracted', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsReprocessing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReprocessing', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsReprocessingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReprocessing', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsUnread() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnread', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortByIsUnreadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnread', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySequenceNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceNumber', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySequenceNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceNumber', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionDurationSeconds', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionDurationSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionDurationSeconds', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionEnd', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionEndDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionEnd', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionStart', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySessionStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionStart', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySynthesizedContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesizedContent', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  sortBySynthesizedContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesizedContent', Sort.desc);
    });
  }
}

extension SynthesisSessionRecordQuerySortThenBy
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QSortThenBy
        > {
  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByAppliedStyleId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedStyleId', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByAppliedStyleIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedStyleId', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByClusterId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterId', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByClusterIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterId', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByFolder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folder', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByFolderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folder', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsActionExtracted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActionExtracted', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsActionExtractedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActionExtracted', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsReprocessing() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReprocessing', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsReprocessingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReprocessing', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsUnread() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnread', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenByIsUnreadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isUnread', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySequenceNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceNumber', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySequenceNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceNumber', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionDurationSeconds', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionDurationSecondsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionDurationSeconds', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionEnd', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionEndDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionEnd', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionStart', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySessionStartDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionStart', Sort.desc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySynthesizedContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesizedContent', Sort.asc);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QAfterSortBy>
  thenBySynthesizedContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesizedContent', Sort.desc);
    });
  }
}

extension SynthesisSessionRecordQueryWhereDistinct
    on QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct> {
  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByAppliedStyleId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'appliedStyleId',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByClusterId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clusterId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByFolder({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'folder', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByIsActionExtracted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActionExtracted');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByIsReprocessing() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isReprocessing');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctByIsUnread() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isUnread');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctBySequenceNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'sequenceNumber',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctBySessionDurationSeconds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionDurationSeconds');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctBySessionEnd() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionEnd');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctBySessionStart() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionStart');
    });
  }

  QueryBuilder<SynthesisSessionRecord, SynthesisSessionRecord, QDistinct>
  distinctBySynthesizedContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'synthesizedContent',
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension SynthesisSessionRecordQueryProperty
    on
        QueryBuilder<
          SynthesisSessionRecord,
          SynthesisSessionRecord,
          QQueryProperty
        > {
  QueryBuilder<SynthesisSessionRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SynthesisSessionRecord, String, QQueryOperations>
  appliedStyleIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appliedStyleId');
    });
  }

  QueryBuilder<SynthesisSessionRecord, String, QQueryOperations>
  clusterIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clusterId');
    });
  }

  QueryBuilder<SynthesisSessionRecord, String, QQueryOperations>
  folderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'folder');
    });
  }

  QueryBuilder<SynthesisSessionRecord, bool, QQueryOperations>
  isActionExtractedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActionExtracted');
    });
  }

  QueryBuilder<SynthesisSessionRecord, bool, QQueryOperations>
  isReprocessingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isReprocessing');
    });
  }

  QueryBuilder<SynthesisSessionRecord, bool, QQueryOperations>
  isUnreadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isUnread');
    });
  }

  QueryBuilder<
    SynthesisSessionRecord,
    List<SynthesisOriginRecord>,
    QQueryOperations
  >
  originNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originNotes');
    });
  }

  QueryBuilder<SynthesisSessionRecord, String, QQueryOperations>
  sequenceNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sequenceNumber');
    });
  }

  QueryBuilder<SynthesisSessionRecord, int, QQueryOperations>
  sessionDurationSecondsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionDurationSeconds');
    });
  }

  QueryBuilder<SynthesisSessionRecord, DateTime, QQueryOperations>
  sessionEndProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionEnd');
    });
  }

  QueryBuilder<SynthesisSessionRecord, DateTime, QQueryOperations>
  sessionStartProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionStart');
    });
  }

  QueryBuilder<SynthesisSessionRecord, String, QQueryOperations>
  synthesizedContentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synthesizedContent');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const SynthesisOriginRecordSchema = Schema(
  name: r'SynthesisOriginRecord',
  id: 8555410894373643158,
  properties: {
    r'audioPath': PropertySchema(
      id: 0,
      name: r'audioPath',
      type: IsarType.string,
    ),
    r'cleanedText': PropertySchema(
      id: 1,
      name: r'cleanedText',
      type: IsarType.string,
    ),
    r'formattedSequence': PropertySchema(
      id: 2,
      name: r'formattedSequence',
      type: IsarType.string,
    ),
    r'noteId': PropertySchema(id: 3, name: r'noteId', type: IsarType.long),
    r'timestamp': PropertySchema(
      id: 4,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _synthesisOriginRecordEstimateSize,
  serialize: _synthesisOriginRecordSerialize,
  deserialize: _synthesisOriginRecordDeserialize,
  deserializeProp: _synthesisOriginRecordDeserializeProp,
);

int _synthesisOriginRecordEstimateSize(
  SynthesisOriginRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.audioPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.cleanedText.length * 3;
  bytesCount += 3 + object.formattedSequence.length * 3;
  return bytesCount;
}

void _synthesisOriginRecordSerialize(
  SynthesisOriginRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.audioPath);
  writer.writeString(offsets[1], object.cleanedText);
  writer.writeString(offsets[2], object.formattedSequence);
  writer.writeLong(offsets[3], object.noteId);
  writer.writeDateTime(offsets[4], object.timestamp);
}

SynthesisOriginRecord _synthesisOriginRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SynthesisOriginRecord();
  object.audioPath = reader.readStringOrNull(offsets[0]);
  object.cleanedText = reader.readString(offsets[1]);
  object.formattedSequence = reader.readString(offsets[2]);
  object.noteId = reader.readLong(offsets[3]);
  object.timestamp = reader.readDateTimeOrNull(offsets[4]);
  return object;
}

P _synthesisOriginRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension SynthesisOriginRecordQueryFilter
    on
        QueryBuilder<
          SynthesisOriginRecord,
          SynthesisOriginRecord,
          QFilterCondition
        > {
  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'audioPath'),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'audioPath'),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'audioPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'audioPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'audioPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'audioPath', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  audioPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'audioPath', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cleanedText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cleanedText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cleanedText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cleanedText', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  cleanedTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cleanedText', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'formattedSequence',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'formattedSequence',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'formattedSequence',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'formattedSequence', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  formattedSequenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'formattedSequence', value: ''),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  noteIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'noteId', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  noteIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'noteId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  noteIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'noteId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  noteIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'noteId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'timestamp'),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'timestamp'),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SynthesisOriginRecord,
    SynthesisOriginRecord,
    QAfterFilterCondition
  >
  timestampBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SynthesisOriginRecordQueryObject
    on
        QueryBuilder<
          SynthesisOriginRecord,
          SynthesisOriginRecord,
          QFilterCondition
        > {}
