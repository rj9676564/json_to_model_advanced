```yaml
dependencies:
  json_to_model_advanced: ^0.0.1
dev_dependencies:
  json_to_model_advanced_generator: ^0.0.1
```

## Model
```dart

@JsonSerializable()
class Task {
  const Task({this.id, this.name, this.avatar, this.createdAt});

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  final String? id;
  final String? name;
  final String? avatar;
  final String? createdAt;

  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
```
wrapperType your BaseModel 
fromJson jsonToModel name
```dart
@JsonToModel(wrapperType: 'BaseResult', wrapperFromJson: 'fromJson')
abstract class JsonClient {
factory JsonClient() = _JsonClient;

BaseResult<List<Task>> getTasks(Map<String,dynamic> json);
BaseResult<List<ClassesStudents>> getClassesStudents(Map<String,dynamic> json);
}
```
Run 
- flutter pub run build_runner build --delete-conflicting-outputs

- flutter pub run build_runner build



