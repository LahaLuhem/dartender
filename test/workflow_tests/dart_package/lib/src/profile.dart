import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

/// Someone's awesomeness, as it travels over the wire.
@JsonSerializable()
class const Profile({
  /// Their name.
  required final String name,

  /// Whether they are awesome.
  required final bool isAwesome,
}) {
  /// Creates it.
  this;

  /// Reads one back from JSON.
  factory fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

  /// Turns it into JSON.
  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}
