// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MountainsTable extends Mountains
    with TableInfo<$MountainsTable, Mountain> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MountainsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elevationMMeta = const VerificationMeta(
    'elevationM',
  );
  @override
  late final GeneratedColumn<int> elevationM = GeneratedColumn<int>(
    'elevation_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Difficulty?, String> difficulty =
      GeneratedColumn<String>(
        'difficulty',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Difficulty?>($MountainsTable.$converterdifficultyn);
  static const VerificationMeta _jumpOffPointMeta = const VerificationMeta(
    'jumpOffPoint',
  );
  @override
  late final GeneratedColumn<String> jumpOffPoint = GeneratedColumn<String>(
    'jump_off_point',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedHoursMeta = const VerificationMeta(
    'estimatedHours',
  );
  @override
  late final GeneratedColumn<double> estimatedHours = GeneratedColumn<double>(
    'estimated_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    region,
    elevationM,
    difficulty,
    jumpOffPoint,
    estimatedHours,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mountains';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mountain> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('elevation_m')) {
      context.handle(
        _elevationMMeta,
        elevationM.isAcceptableOrUnknown(data['elevation_m']!, _elevationMMeta),
      );
    }
    if (data.containsKey('jump_off_point')) {
      context.handle(
        _jumpOffPointMeta,
        jumpOffPoint.isAcceptableOrUnknown(
          data['jump_off_point']!,
          _jumpOffPointMeta,
        ),
      );
    }
    if (data.containsKey('estimated_hours')) {
      context.handle(
        _estimatedHoursMeta,
        estimatedHours.isAcceptableOrUnknown(
          data['estimated_hours']!,
          _estimatedHoursMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mountain map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mountain(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      elevationM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elevation_m'],
      ),
      difficulty: $MountainsTable.$converterdifficultyn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}difficulty'],
        ),
      ),
      jumpOffPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jump_off_point'],
      ),
      estimatedHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_hours'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $MountainsTable createAlias(String alias) {
    return $MountainsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Difficulty, String, String> $converterdifficulty =
      const EnumNameConverter<Difficulty>(Difficulty.values);
  static JsonTypeConverter2<Difficulty?, String?, String?>
  $converterdifficultyn = JsonTypeConverter2.asNullable($converterdifficulty);
}

class Mountain extends DataClass implements Insertable<Mountain> {
  final int id;

  /// Unique, so the seed can insert-or-ignore and stay idempotent.
  final String name;
  final String? region;
  final int? elevationM;
  final Difficulty? difficulty;
  final String? jumpOffPoint;

  /// Hours, not minutes, and fractional: a peak can be a 3.5 hour walk.
  final double? estimatedHours;
  final String? notes;
  const Mountain({
    required this.id,
    required this.name,
    this.region,
    this.elevationM,
    this.difficulty,
    this.jumpOffPoint,
    this.estimatedHours,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || elevationM != null) {
      map['elevation_m'] = Variable<int>(elevationM);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<String>(
        $MountainsTable.$converterdifficultyn.toSql(difficulty),
      );
    }
    if (!nullToAbsent || jumpOffPoint != null) {
      map['jump_off_point'] = Variable<String>(jumpOffPoint);
    }
    if (!nullToAbsent || estimatedHours != null) {
      map['estimated_hours'] = Variable<double>(estimatedHours);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  MountainsCompanion toCompanion(bool nullToAbsent) {
    return MountainsCompanion(
      id: Value(id),
      name: Value(name),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      elevationM: elevationM == null && nullToAbsent
          ? const Value.absent()
          : Value(elevationM),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      jumpOffPoint: jumpOffPoint == null && nullToAbsent
          ? const Value.absent()
          : Value(jumpOffPoint),
      estimatedHours: estimatedHours == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedHours),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Mountain.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mountain(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      region: serializer.fromJson<String?>(json['region']),
      elevationM: serializer.fromJson<int?>(json['elevationM']),
      difficulty: $MountainsTable.$converterdifficultyn.fromJson(
        serializer.fromJson<String?>(json['difficulty']),
      ),
      jumpOffPoint: serializer.fromJson<String?>(json['jumpOffPoint']),
      estimatedHours: serializer.fromJson<double?>(json['estimatedHours']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'region': serializer.toJson<String?>(region),
      'elevationM': serializer.toJson<int?>(elevationM),
      'difficulty': serializer.toJson<String?>(
        $MountainsTable.$converterdifficultyn.toJson(difficulty),
      ),
      'jumpOffPoint': serializer.toJson<String?>(jumpOffPoint),
      'estimatedHours': serializer.toJson<double?>(estimatedHours),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Mountain copyWith({
    int? id,
    String? name,
    Value<String?> region = const Value.absent(),
    Value<int?> elevationM = const Value.absent(),
    Value<Difficulty?> difficulty = const Value.absent(),
    Value<String?> jumpOffPoint = const Value.absent(),
    Value<double?> estimatedHours = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Mountain(
    id: id ?? this.id,
    name: name ?? this.name,
    region: region.present ? region.value : this.region,
    elevationM: elevationM.present ? elevationM.value : this.elevationM,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    jumpOffPoint: jumpOffPoint.present ? jumpOffPoint.value : this.jumpOffPoint,
    estimatedHours: estimatedHours.present
        ? estimatedHours.value
        : this.estimatedHours,
    notes: notes.present ? notes.value : this.notes,
  );
  Mountain copyWithCompanion(MountainsCompanion data) {
    return Mountain(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      region: data.region.present ? data.region.value : this.region,
      elevationM: data.elevationM.present
          ? data.elevationM.value
          : this.elevationM,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      jumpOffPoint: data.jumpOffPoint.present
          ? data.jumpOffPoint.value
          : this.jumpOffPoint,
      estimatedHours: data.estimatedHours.present
          ? data.estimatedHours.value
          : this.estimatedHours,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mountain(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('region: $region, ')
          ..write('elevationM: $elevationM, ')
          ..write('difficulty: $difficulty, ')
          ..write('jumpOffPoint: $jumpOffPoint, ')
          ..write('estimatedHours: $estimatedHours, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    region,
    elevationM,
    difficulty,
    jumpOffPoint,
    estimatedHours,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mountain &&
          other.id == this.id &&
          other.name == this.name &&
          other.region == this.region &&
          other.elevationM == this.elevationM &&
          other.difficulty == this.difficulty &&
          other.jumpOffPoint == this.jumpOffPoint &&
          other.estimatedHours == this.estimatedHours &&
          other.notes == this.notes);
}

class MountainsCompanion extends UpdateCompanion<Mountain> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> region;
  final Value<int?> elevationM;
  final Value<Difficulty?> difficulty;
  final Value<String?> jumpOffPoint;
  final Value<double?> estimatedHours;
  final Value<String?> notes;
  const MountainsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.region = const Value.absent(),
    this.elevationM = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.jumpOffPoint = const Value.absent(),
    this.estimatedHours = const Value.absent(),
    this.notes = const Value.absent(),
  });
  MountainsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.region = const Value.absent(),
    this.elevationM = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.jumpOffPoint = const Value.absent(),
    this.estimatedHours = const Value.absent(),
    this.notes = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Mountain> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? region,
    Expression<int>? elevationM,
    Expression<String>? difficulty,
    Expression<String>? jumpOffPoint,
    Expression<double>? estimatedHours,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (region != null) 'region': region,
      if (elevationM != null) 'elevation_m': elevationM,
      if (difficulty != null) 'difficulty': difficulty,
      if (jumpOffPoint != null) 'jump_off_point': jumpOffPoint,
      if (estimatedHours != null) 'estimated_hours': estimatedHours,
      if (notes != null) 'notes': notes,
    });
  }

  MountainsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? region,
    Value<int?>? elevationM,
    Value<Difficulty?>? difficulty,
    Value<String?>? jumpOffPoint,
    Value<double?>? estimatedHours,
    Value<String?>? notes,
  }) {
    return MountainsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      elevationM: elevationM ?? this.elevationM,
      difficulty: difficulty ?? this.difficulty,
      jumpOffPoint: jumpOffPoint ?? this.jumpOffPoint,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (elevationM.present) {
      map['elevation_m'] = Variable<int>(elevationM.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(
        $MountainsTable.$converterdifficultyn.toSql(difficulty.value),
      );
    }
    if (jumpOffPoint.present) {
      map['jump_off_point'] = Variable<String>(jumpOffPoint.value);
    }
    if (estimatedHours.present) {
      map['estimated_hours'] = Variable<double>(estimatedHours.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MountainsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('region: $region, ')
          ..write('elevationM: $elevationM, ')
          ..write('difficulty: $difficulty, ')
          ..write('jumpOffPoint: $jumpOffPoint, ')
          ..write('estimatedHours: $estimatedHours, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $ClimbsTable extends Climbs with TableInfo<$ClimbsTable, Climb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClimbsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mountainIdMeta = const VerificationMeta(
    'mountainId',
  );
  @override
  late final GeneratedColumn<int> mountainId = GeneratedColumn<int>(
    'mountain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mountains (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> date =
      GeneratedColumn<String>(
        'date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ClimbsTable.$converterdate);
  static const VerificationMeta _companionsMeta = const VerificationMeta(
    'companions',
  );
  @override
  late final GeneratedColumn<String> companions = GeneratedColumn<String>(
    'companions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  photoFilenames = GeneratedColumn<String>(
    'photo_filenames',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($ClimbsTable.$converterphotoFilenames);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mountainId,
    date,
    companions,
    notes,
    photoFilenames,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'climbs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Climb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mountain_id')) {
      context.handle(
        _mountainIdMeta,
        mountainId.isAcceptableOrUnknown(data['mountain_id']!, _mountainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mountainIdMeta);
    }
    if (data.containsKey('companions')) {
      context.handle(
        _companionsMeta,
        companions.isAcceptableOrUnknown(data['companions']!, _companionsMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Climb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Climb(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mountainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mountain_id'],
      )!,
      date: $ClimbsTable.$converterdate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}date'],
        )!,
      ),
      companions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}companions'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      photoFilenames: $ClimbsTable.$converterphotoFilenames.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}photo_filenames'],
        )!,
      ),
    );
  }

  @override
  $ClimbsTable createAlias(String alias) {
    return $ClimbsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterdate =
      const DateOnlyConverter();
  static TypeConverter<List<String>, String> $converterphotoFilenames =
      const PhotoFilenamesConverter();
}

class Climb extends DataClass implements Insertable<Climb> {
  final int id;

  /// Deleting a peak takes its climbs with it.
  final int mountainId;

  /// A calendar day, not a timestamp: 11 August stays 11 August whatever the
  /// phone's timezone does. Stored as `YYYY-MM-DD` text by
  /// [DateOnlyConverter]. Required, because a climb with no date is not a climb.
  final DateTime date;
  final String? companions;
  final String? notes;

  /// Empty list by default, so reading a photo-less climb needs no null check.
  final List<String> photoFilenames;
  const Climb({
    required this.id,
    required this.mountainId,
    required this.date,
    this.companions,
    this.notes,
    required this.photoFilenames,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mountain_id'] = Variable<int>(mountainId);
    {
      map['date'] = Variable<String>($ClimbsTable.$converterdate.toSql(date));
    }
    if (!nullToAbsent || companions != null) {
      map['companions'] = Variable<String>(companions);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['photo_filenames'] = Variable<String>(
        $ClimbsTable.$converterphotoFilenames.toSql(photoFilenames),
      );
    }
    return map;
  }

  ClimbsCompanion toCompanion(bool nullToAbsent) {
    return ClimbsCompanion(
      id: Value(id),
      mountainId: Value(mountainId),
      date: Value(date),
      companions: companions == null && nullToAbsent
          ? const Value.absent()
          : Value(companions),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      photoFilenames: Value(photoFilenames),
    );
  }

  factory Climb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Climb(
      id: serializer.fromJson<int>(json['id']),
      mountainId: serializer.fromJson<int>(json['mountainId']),
      date: serializer.fromJson<DateTime>(json['date']),
      companions: serializer.fromJson<String?>(json['companions']),
      notes: serializer.fromJson<String?>(json['notes']),
      photoFilenames: serializer.fromJson<List<String>>(json['photoFilenames']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mountainId': serializer.toJson<int>(mountainId),
      'date': serializer.toJson<DateTime>(date),
      'companions': serializer.toJson<String?>(companions),
      'notes': serializer.toJson<String?>(notes),
      'photoFilenames': serializer.toJson<List<String>>(photoFilenames),
    };
  }

  Climb copyWith({
    int? id,
    int? mountainId,
    DateTime? date,
    Value<String?> companions = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    List<String>? photoFilenames,
  }) => Climb(
    id: id ?? this.id,
    mountainId: mountainId ?? this.mountainId,
    date: date ?? this.date,
    companions: companions.present ? companions.value : this.companions,
    notes: notes.present ? notes.value : this.notes,
    photoFilenames: photoFilenames ?? this.photoFilenames,
  );
  Climb copyWithCompanion(ClimbsCompanion data) {
    return Climb(
      id: data.id.present ? data.id.value : this.id,
      mountainId: data.mountainId.present
          ? data.mountainId.value
          : this.mountainId,
      date: data.date.present ? data.date.value : this.date,
      companions: data.companions.present
          ? data.companions.value
          : this.companions,
      notes: data.notes.present ? data.notes.value : this.notes,
      photoFilenames: data.photoFilenames.present
          ? data.photoFilenames.value
          : this.photoFilenames,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Climb(')
          ..write('id: $id, ')
          ..write('mountainId: $mountainId, ')
          ..write('date: $date, ')
          ..write('companions: $companions, ')
          ..write('notes: $notes, ')
          ..write('photoFilenames: $photoFilenames')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mountainId, date, companions, notes, photoFilenames);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Climb &&
          other.id == this.id &&
          other.mountainId == this.mountainId &&
          other.date == this.date &&
          other.companions == this.companions &&
          other.notes == this.notes &&
          other.photoFilenames == this.photoFilenames);
}

class ClimbsCompanion extends UpdateCompanion<Climb> {
  final Value<int> id;
  final Value<int> mountainId;
  final Value<DateTime> date;
  final Value<String?> companions;
  final Value<String?> notes;
  final Value<List<String>> photoFilenames;
  const ClimbsCompanion({
    this.id = const Value.absent(),
    this.mountainId = const Value.absent(),
    this.date = const Value.absent(),
    this.companions = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoFilenames = const Value.absent(),
  });
  ClimbsCompanion.insert({
    this.id = const Value.absent(),
    required int mountainId,
    required DateTime date,
    this.companions = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoFilenames = const Value.absent(),
  }) : mountainId = Value(mountainId),
       date = Value(date);
  static Insertable<Climb> custom({
    Expression<int>? id,
    Expression<int>? mountainId,
    Expression<String>? date,
    Expression<String>? companions,
    Expression<String>? notes,
    Expression<String>? photoFilenames,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mountainId != null) 'mountain_id': mountainId,
      if (date != null) 'date': date,
      if (companions != null) 'companions': companions,
      if (notes != null) 'notes': notes,
      if (photoFilenames != null) 'photo_filenames': photoFilenames,
    });
  }

  ClimbsCompanion copyWith({
    Value<int>? id,
    Value<int>? mountainId,
    Value<DateTime>? date,
    Value<String?>? companions,
    Value<String?>? notes,
    Value<List<String>>? photoFilenames,
  }) {
    return ClimbsCompanion(
      id: id ?? this.id,
      mountainId: mountainId ?? this.mountainId,
      date: date ?? this.date,
      companions: companions ?? this.companions,
      notes: notes ?? this.notes,
      photoFilenames: photoFilenames ?? this.photoFilenames,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mountainId.present) {
      map['mountain_id'] = Variable<int>(mountainId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(
        $ClimbsTable.$converterdate.toSql(date.value),
      );
    }
    if (companions.present) {
      map['companions'] = Variable<String>(companions.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (photoFilenames.present) {
      map['photo_filenames'] = Variable<String>(
        $ClimbsTable.$converterphotoFilenames.toSql(photoFilenames.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClimbsCompanion(')
          ..write('id: $id, ')
          ..write('mountainId: $mountainId, ')
          ..write('date: $date, ')
          ..write('companions: $companions, ')
          ..write('notes: $notes, ')
          ..write('photoFilenames: $photoFilenames')
          ..write(')'))
        .toString();
  }
}

class $AchievementsTable extends Achievements
    with TableInfo<$AchievementsTable, Achievement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AchievementType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AchievementType>($AchievementsTable.$convertertype);
  static const VerificationMeta _unlockedAtMeta = const VerificationMeta(
    'unlockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
    'unlocked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mountainIdMeta = const VerificationMeta(
    'mountainId',
  );
  @override
  late final GeneratedColumn<int> mountainId = GeneratedColumn<int>(
    'mountain_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mountains (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, type, unlockedAt, mountainId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Achievement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
        _unlockedAtMeta,
        unlockedAt.isAcceptableOrUnknown(data['unlocked_at']!, _unlockedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedAtMeta);
    }
    if (data.containsKey('mountain_id')) {
      context.handle(
        _mountainIdMeta,
        mountainId.isAcceptableOrUnknown(data['mountain_id']!, _mountainIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Achievement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Achievement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $AchievementsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      unlockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unlocked_at'],
      )!,
      mountainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mountain_id'],
      ),
    );
  }

  @override
  $AchievementsTable createAlias(String alias) {
    return $AchievementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AchievementType, String, String> $convertertype =
      const EnumNameConverter<AchievementType>(AchievementType.values);
}

class Achievement extends DataClass implements Insertable<Achievement> {
  final int id;
  final AchievementType type;

  /// A real timestamp, not a calendar day: the moment the badge fired. Left on
  /// Drift's default epoch-second storage, because the instant is the point.
  /// Contrast `climbs.date`, a day that must not move when the timezone does.
  final DateTime unlockedAt;

  /// Null for a milestone badge. Deleting a peak takes its badge with it.
  final int? mountainId;
  const Achievement({
    required this.id,
    required this.type,
    required this.unlockedAt,
    this.mountainId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $AchievementsTable.$convertertype.toSql(type),
      );
    }
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    if (!nullToAbsent || mountainId != null) {
      map['mountain_id'] = Variable<int>(mountainId);
    }
    return map;
  }

  AchievementsCompanion toCompanion(bool nullToAbsent) {
    return AchievementsCompanion(
      id: Value(id),
      type: Value(type),
      unlockedAt: Value(unlockedAt),
      mountainId: mountainId == null && nullToAbsent
          ? const Value.absent()
          : Value(mountainId),
    );
  }

  factory Achievement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Achievement(
      id: serializer.fromJson<int>(json['id']),
      type: $AchievementsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
      mountainId: serializer.fromJson<int?>(json['mountainId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $AchievementsTable.$convertertype.toJson(type),
      ),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
      'mountainId': serializer.toJson<int?>(mountainId),
    };
  }

  Achievement copyWith({
    int? id,
    AchievementType? type,
    DateTime? unlockedAt,
    Value<int?> mountainId = const Value.absent(),
  }) => Achievement(
    id: id ?? this.id,
    type: type ?? this.type,
    unlockedAt: unlockedAt ?? this.unlockedAt,
    mountainId: mountainId.present ? mountainId.value : this.mountainId,
  );
  Achievement copyWithCompanion(AchievementsCompanion data) {
    return Achievement(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      unlockedAt: data.unlockedAt.present
          ? data.unlockedAt.value
          : this.unlockedAt,
      mountainId: data.mountainId.present
          ? data.mountainId.value
          : this.mountainId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Achievement(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('mountainId: $mountainId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, unlockedAt, mountainId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Achievement &&
          other.id == this.id &&
          other.type == this.type &&
          other.unlockedAt == this.unlockedAt &&
          other.mountainId == this.mountainId);
}

class AchievementsCompanion extends UpdateCompanion<Achievement> {
  final Value<int> id;
  final Value<AchievementType> type;
  final Value<DateTime> unlockedAt;
  final Value<int?> mountainId;
  const AchievementsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.mountainId = const Value.absent(),
  });
  AchievementsCompanion.insert({
    this.id = const Value.absent(),
    required AchievementType type,
    required DateTime unlockedAt,
    this.mountainId = const Value.absent(),
  }) : type = Value(type),
       unlockedAt = Value(unlockedAt);
  static Insertable<Achievement> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<DateTime>? unlockedAt,
    Expression<int>? mountainId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (mountainId != null) 'mountain_id': mountainId,
    });
  }

  AchievementsCompanion copyWith({
    Value<int>? id,
    Value<AchievementType>? type,
    Value<DateTime>? unlockedAt,
    Value<int?>? mountainId,
  }) {
    return AchievementsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      mountainId: mountainId ?? this.mountainId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AchievementsTable.$convertertype.toSql(type.value),
      );
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (mountainId.present) {
      map['mountain_id'] = Variable<int>(mountainId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AchievementsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('mountainId: $mountainId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MountainsTable mountains = $MountainsTable(this);
  late final $ClimbsTable climbs = $ClimbsTable(this);
  late final $AchievementsTable achievements = $AchievementsTable(this);
  late final Index idxClimbsMountainId = Index(
    'idx_climbs_mountain_id',
    'CREATE INDEX idx_climbs_mountain_id ON climbs (mountain_id)',
  );
  late final Index idxClimbsDate = Index(
    'idx_climbs_date',
    'CREATE INDEX idx_climbs_date ON climbs (date)',
  );
  late final Index uxAchievementsPeak = Index(
    'ux_achievements_peak',
    'CREATE UNIQUE INDEX ux_achievements_peak ON achievements (type, mountain_id) WHERE mountain_id IS NOT NULL',
  );
  late final Index uxAchievementsMilestone = Index(
    'ux_achievements_milestone',
    'CREATE UNIQUE INDEX ux_achievements_milestone ON achievements (type) WHERE mountain_id IS NULL',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mountains,
    climbs,
    achievements,
    idxClimbsMountainId,
    idxClimbsDate,
    uxAchievementsPeak,
    uxAchievementsMilestone,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mountains',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('climbs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mountains',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('achievements', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MountainsTableCreateCompanionBuilder =
    MountainsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> region,
      Value<int?> elevationM,
      Value<Difficulty?> difficulty,
      Value<String?> jumpOffPoint,
      Value<double?> estimatedHours,
      Value<String?> notes,
    });
typedef $$MountainsTableUpdateCompanionBuilder =
    MountainsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> region,
      Value<int?> elevationM,
      Value<Difficulty?> difficulty,
      Value<String?> jumpOffPoint,
      Value<double?> estimatedHours,
      Value<String?> notes,
    });

final class $$MountainsTableReferences
    extends BaseReferences<_$AppDatabase, $MountainsTable, Mountain> {
  $$MountainsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClimbsTable, List<Climb>> _climbsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.climbs,
    aliasName: 'mountains__id__climbs__mountain_id',
  );

  $$ClimbsTableProcessedTableManager get climbsRefs {
    final manager = $$ClimbsTableTableManager(
      $_db,
      $_db.climbs,
    ).filter((f) => f.mountainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_climbsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AchievementsTable, List<Achievement>>
  _achievementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.achievements,
    aliasName: 'mountains__id__achievements__mountain_id',
  );

  $$AchievementsTableProcessedTableManager get achievementsRefs {
    final manager = $$AchievementsTableTableManager(
      $_db,
      $_db.achievements,
    ).filter((f) => f.mountainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_achievementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MountainsTableFilterComposer
    extends Composer<_$AppDatabase, $MountainsTable> {
  $$MountainsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elevationM => $composableBuilder(
    column: $table.elevationM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Difficulty?, Difficulty, String>
  get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get jumpOffPoint => $composableBuilder(
    column: $table.jumpOffPoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimatedHours => $composableBuilder(
    column: $table.estimatedHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> climbsRefs(
    Expression<bool> Function($$ClimbsTableFilterComposer f) f,
  ) {
    final $$ClimbsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.climbs,
      getReferencedColumn: (t) => t.mountainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClimbsTableFilterComposer(
            $db: $db,
            $table: $db.climbs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> achievementsRefs(
    Expression<bool> Function($$AchievementsTableFilterComposer f) f,
  ) {
    final $$AchievementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.achievements,
      getReferencedColumn: (t) => t.mountainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AchievementsTableFilterComposer(
            $db: $db,
            $table: $db.achievements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MountainsTableOrderingComposer
    extends Composer<_$AppDatabase, $MountainsTable> {
  $$MountainsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elevationM => $composableBuilder(
    column: $table.elevationM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jumpOffPoint => $composableBuilder(
    column: $table.jumpOffPoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedHours => $composableBuilder(
    column: $table.estimatedHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MountainsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MountainsTable> {
  $$MountainsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<int> get elevationM => $composableBuilder(
    column: $table.elevationM,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Difficulty?, String> get difficulty =>
      $composableBuilder(
        column: $table.difficulty,
        builder: (column) => column,
      );

  GeneratedColumn<String> get jumpOffPoint => $composableBuilder(
    column: $table.jumpOffPoint,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estimatedHours => $composableBuilder(
    column: $table.estimatedHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> climbsRefs<T extends Object>(
    Expression<T> Function($$ClimbsTableAnnotationComposer a) f,
  ) {
    final $$ClimbsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.climbs,
      getReferencedColumn: (t) => t.mountainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClimbsTableAnnotationComposer(
            $db: $db,
            $table: $db.climbs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> achievementsRefs<T extends Object>(
    Expression<T> Function($$AchievementsTableAnnotationComposer a) f,
  ) {
    final $$AchievementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.achievements,
      getReferencedColumn: (t) => t.mountainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AchievementsTableAnnotationComposer(
            $db: $db,
            $table: $db.achievements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MountainsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MountainsTable,
          Mountain,
          $$MountainsTableFilterComposer,
          $$MountainsTableOrderingComposer,
          $$MountainsTableAnnotationComposer,
          $$MountainsTableCreateCompanionBuilder,
          $$MountainsTableUpdateCompanionBuilder,
          (Mountain, $$MountainsTableReferences),
          Mountain,
          PrefetchHooks Function({bool climbsRefs, bool achievementsRefs})
        > {
  $$MountainsTableTableManager(_$AppDatabase db, $MountainsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MountainsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MountainsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MountainsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<int?> elevationM = const Value.absent(),
                Value<Difficulty?> difficulty = const Value.absent(),
                Value<String?> jumpOffPoint = const Value.absent(),
                Value<double?> estimatedHours = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => MountainsCompanion(
                id: id,
                name: name,
                region: region,
                elevationM: elevationM,
                difficulty: difficulty,
                jumpOffPoint: jumpOffPoint,
                estimatedHours: estimatedHours,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> region = const Value.absent(),
                Value<int?> elevationM = const Value.absent(),
                Value<Difficulty?> difficulty = const Value.absent(),
                Value<String?> jumpOffPoint = const Value.absent(),
                Value<double?> estimatedHours = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => MountainsCompanion.insert(
                id: id,
                name: name,
                region: region,
                elevationM: elevationM,
                difficulty: difficulty,
                jumpOffPoint: jumpOffPoint,
                estimatedHours: estimatedHours,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MountainsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({climbsRefs = false, achievementsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (climbsRefs) db.climbs,
                    if (achievementsRefs) db.achievements,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (climbsRefs)
                        await $_getPrefetchedData<
                          Mountain,
                          $MountainsTable,
                          Climb
                        >(
                          currentTable: table,
                          referencedTable: $$MountainsTableReferences
                              ._climbsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MountainsTableReferences(
                                db,
                                table,
                                p0,
                              ).climbsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mountainId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (achievementsRefs)
                        await $_getPrefetchedData<
                          Mountain,
                          $MountainsTable,
                          Achievement
                        >(
                          currentTable: table,
                          referencedTable: $$MountainsTableReferences
                              ._achievementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MountainsTableReferences(
                                db,
                                table,
                                p0,
                              ).achievementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mountainId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MountainsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MountainsTable,
      Mountain,
      $$MountainsTableFilterComposer,
      $$MountainsTableOrderingComposer,
      $$MountainsTableAnnotationComposer,
      $$MountainsTableCreateCompanionBuilder,
      $$MountainsTableUpdateCompanionBuilder,
      (Mountain, $$MountainsTableReferences),
      Mountain,
      PrefetchHooks Function({bool climbsRefs, bool achievementsRefs})
    >;
typedef $$ClimbsTableCreateCompanionBuilder =
    ClimbsCompanion Function({
      Value<int> id,
      required int mountainId,
      required DateTime date,
      Value<String?> companions,
      Value<String?> notes,
      Value<List<String>> photoFilenames,
    });
typedef $$ClimbsTableUpdateCompanionBuilder =
    ClimbsCompanion Function({
      Value<int> id,
      Value<int> mountainId,
      Value<DateTime> date,
      Value<String?> companions,
      Value<String?> notes,
      Value<List<String>> photoFilenames,
    });

final class $$ClimbsTableReferences
    extends BaseReferences<_$AppDatabase, $ClimbsTable, Climb> {
  $$ClimbsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MountainsTable _mountainIdTable(_$AppDatabase db) =>
      db.mountains.createAlias('climbs__mountain_id__mountains__id');

  $$MountainsTableProcessedTableManager get mountainId {
    final $_column = $_itemColumn<int>('mountain_id')!;

    final manager = $$MountainsTableTableManager(
      $_db,
      $_db.mountains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mountainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClimbsTableFilterComposer
    extends Composer<_$AppDatabase, $ClimbsTable> {
  $$ClimbsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get date =>
      $composableBuilder(
        column: $table.date,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get companions => $composableBuilder(
    column: $table.companions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get photoFilenames => $composableBuilder(
    column: $table.photoFilenames,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$MountainsTableFilterComposer get mountainId {
    final $$MountainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableFilterComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClimbsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClimbsTable> {
  $$ClimbsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companions => $composableBuilder(
    column: $table.companions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoFilenames => $composableBuilder(
    column: $table.photoFilenames,
    builder: (column) => ColumnOrderings(column),
  );

  $$MountainsTableOrderingComposer get mountainId {
    final $$MountainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableOrderingComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClimbsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClimbsTable> {
  $$ClimbsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get companions => $composableBuilder(
    column: $table.companions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get photoFilenames =>
      $composableBuilder(
        column: $table.photoFilenames,
        builder: (column) => column,
      );

  $$MountainsTableAnnotationComposer get mountainId {
    final $$MountainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableAnnotationComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClimbsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClimbsTable,
          Climb,
          $$ClimbsTableFilterComposer,
          $$ClimbsTableOrderingComposer,
          $$ClimbsTableAnnotationComposer,
          $$ClimbsTableCreateCompanionBuilder,
          $$ClimbsTableUpdateCompanionBuilder,
          (Climb, $$ClimbsTableReferences),
          Climb,
          PrefetchHooks Function({bool mountainId})
        > {
  $$ClimbsTableTableManager(_$AppDatabase db, $ClimbsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClimbsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClimbsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClimbsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mountainId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> companions = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<List<String>> photoFilenames = const Value.absent(),
              }) => ClimbsCompanion(
                id: id,
                mountainId: mountainId,
                date: date,
                companions: companions,
                notes: notes,
                photoFilenames: photoFilenames,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mountainId,
                required DateTime date,
                Value<String?> companions = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<List<String>> photoFilenames = const Value.absent(),
              }) => ClimbsCompanion.insert(
                id: id,
                mountainId: mountainId,
                date: date,
                companions: companions,
                notes: notes,
                photoFilenames: photoFilenames,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ClimbsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({mountainId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mountainId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mountainId,
                                referencedTable: $$ClimbsTableReferences
                                    ._mountainIdTable(db),
                                referencedColumn: $$ClimbsTableReferences
                                    ._mountainIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClimbsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClimbsTable,
      Climb,
      $$ClimbsTableFilterComposer,
      $$ClimbsTableOrderingComposer,
      $$ClimbsTableAnnotationComposer,
      $$ClimbsTableCreateCompanionBuilder,
      $$ClimbsTableUpdateCompanionBuilder,
      (Climb, $$ClimbsTableReferences),
      Climb,
      PrefetchHooks Function({bool mountainId})
    >;
typedef $$AchievementsTableCreateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      required AchievementType type,
      required DateTime unlockedAt,
      Value<int?> mountainId,
    });
typedef $$AchievementsTableUpdateCompanionBuilder =
    AchievementsCompanion Function({
      Value<int> id,
      Value<AchievementType> type,
      Value<DateTime> unlockedAt,
      Value<int?> mountainId,
    });

final class $$AchievementsTableReferences
    extends BaseReferences<_$AppDatabase, $AchievementsTable, Achievement> {
  $$AchievementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MountainsTable _mountainIdTable(_$AppDatabase db) =>
      db.mountains.createAlias('achievements__mountain_id__mountains__id');

  $$MountainsTableProcessedTableManager? get mountainId {
    final $_column = $_itemColumn<int>('mountain_id');
    if ($_column == null) return null;
    final manager = $$MountainsTableTableManager(
      $_db,
      $_db.mountains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mountainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AchievementType, AchievementType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MountainsTableFilterComposer get mountainId {
    final $$MountainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableFilterComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MountainsTableOrderingComposer get mountainId {
    final $$MountainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableOrderingComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AchievementsTable> {
  $$AchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AchievementType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
    column: $table.unlockedAt,
    builder: (column) => column,
  );

  $$MountainsTableAnnotationComposer get mountainId {
    final $$MountainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mountainId,
      referencedTable: $db.mountains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MountainsTableAnnotationComposer(
            $db: $db,
            $table: $db.mountains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AchievementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AchievementsTable,
          Achievement,
          $$AchievementsTableFilterComposer,
          $$AchievementsTableOrderingComposer,
          $$AchievementsTableAnnotationComposer,
          $$AchievementsTableCreateCompanionBuilder,
          $$AchievementsTableUpdateCompanionBuilder,
          (Achievement, $$AchievementsTableReferences),
          Achievement,
          PrefetchHooks Function({bool mountainId})
        > {
  $$AchievementsTableTableManager(_$AppDatabase db, $AchievementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AchievementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<AchievementType> type = const Value.absent(),
                Value<DateTime> unlockedAt = const Value.absent(),
                Value<int?> mountainId = const Value.absent(),
              }) => AchievementsCompanion(
                id: id,
                type: type,
                unlockedAt: unlockedAt,
                mountainId: mountainId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required AchievementType type,
                required DateTime unlockedAt,
                Value<int?> mountainId = const Value.absent(),
              }) => AchievementsCompanion.insert(
                id: id,
                type: type,
                unlockedAt: unlockedAt,
                mountainId: mountainId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AchievementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mountainId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mountainId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mountainId,
                                referencedTable: $$AchievementsTableReferences
                                    ._mountainIdTable(db),
                                referencedColumn: $$AchievementsTableReferences
                                    ._mountainIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AchievementsTable,
      Achievement,
      $$AchievementsTableFilterComposer,
      $$AchievementsTableOrderingComposer,
      $$AchievementsTableAnnotationComposer,
      $$AchievementsTableCreateCompanionBuilder,
      $$AchievementsTableUpdateCompanionBuilder,
      (Achievement, $$AchievementsTableReferences),
      Achievement,
      PrefetchHooks Function({bool mountainId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MountainsTableTableManager get mountains =>
      $$MountainsTableTableManager(_db, _db.mountains);
  $$ClimbsTableTableManager get climbs =>
      $$ClimbsTableTableManager(_db, _db.climbs);
  $$AchievementsTableTableManager get achievements =>
      $$AchievementsTableTableManager(_db, _db.achievements);
}
