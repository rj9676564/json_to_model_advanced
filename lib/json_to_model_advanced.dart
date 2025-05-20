library json_to_model_advanced;

/// A Calculator.
class JsonToModel {
  final String? wrapperType; // e.g., "BaseModel1" or "BaseModel2"
  final String? wrapperFromJson; // e.g., "fromJson" or "fromMap"
  const JsonToModel({this.wrapperType, this.wrapperFromJson});
}