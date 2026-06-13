import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class DateEntry extends HiveObject {
  @HiveField(0)
  late String spotId;

  @HiveField(1)
  late String spotName;

  @HiveField(2)
  late String imageUrl;

  @HiveField(3)
  late DateTime visitedOn;

  @HiveField(4)
  late int rating;

  @HiveField(5)
  late String note;

  DateEntry({
    required this.spotId,
    required this.spotName,
    required this.imageUrl,
    required this.visitedOn,
    required this.rating,
    required this.note,
  });

  // Empty constructor for Hive
  DateEntry.empty();
}

class DateEntryAdapter extends TypeAdapter<DateEntry> {
  @override
  final int typeId = 0;

  @override
  DateEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DateEntry(
      spotId: fields[0] as String,
      spotName: fields[1] as String,
      imageUrl: fields[2] as String,
      visitedOn: fields[3] as DateTime,
      rating: fields[4] as int,
      note: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DateEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.spotId)
      ..writeByte(1)
      ..write(obj.spotName)
      ..writeByte(2)
      ..write(obj.imageUrl)
      ..writeByte(3)
      ..write(obj.visitedOn)
      ..writeByte(4)
      ..write(obj.rating)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
