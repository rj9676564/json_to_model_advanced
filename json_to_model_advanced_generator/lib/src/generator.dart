import 'dart:async';
import 'package:build/build.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';
import 'package:json_to_model_advanced/json_to_model_advanced.dart';

// Generator for classes annotated with @JsonToModel
class Json2ModelGenerator extends GeneratorForAnnotation<JsonToModel> {
  // Formatter for generating properly formatted Dart code
  final _formatter = DartFormatter();
  // Logger for debugging and tracking generator execution
  final _logger = Logger('Json2ModelGenerator');

  // Checks if a type is a Dart primitive (no fromJson method)
  bool isPrimitiveType(String type) {
    return ['int', 'double', 'String', 'bool', 'num'].contains(type);
  }

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element,
      ConstantReader annotation,
      BuildStep buildStep,
      ) {
    // Log the start of processing for the element
    _logger.info('Processing element: ${element.name}');

    // Ensure the element is a class; skip if not
    if (element is! ClassElement) {
      _logger.warning('Element ${element.name} is not a ClassElement, skipping.');
      return '';
    }

    // No cast needed since 'element is ClassElement' check ensures type
    final classElement = element;
    final className = classElement.name;
    final implClassName = '_$className'; // Generated implementation class name

    _logger.info('Generating implementation for class: $className');

    // Read annotation parameters for wrapper type and fromJson method
    final wrapperType = annotation.read('wrapperType').stringValue;
    final wrapperFromJson = annotation.read('wrapperFromJson').stringValue;
    _logger.info(
        'Annotation config: wrapperType=$wrapperType, wrapperFromJson=$wrapperFromJson');

    // Buffer to build the generated Dart code
    final buffer = StringBuffer();
    buffer.writeln('// Generated implementation class for $className');
    buffer.writeln('class $implClassName implements $className {');

    // Iterate through all methods in the class
    for (final method in classElement.methods) {
      // Skip non-abstract methods as they don't need implementation
      if (!method.isAbstract) {
        _logger.fine('Skipping non-abstract method: ${method.name}');
        continue;
      }

      _logger.info(
          'Processing method: ${method.name} with return type: ${method.returnType}');

      // Extract return type without nullability annotations (default behavior)
      final returnType = method.returnType.getDisplayString();
      final methodName = method.name;
      final parameters = method.parameters.map((param) {
        // Extract parameter type without nullability annotations
        final type = param.type.getDisplayString();
        return '$type ${param.name}';
      }).join(', ');

      // Write method signature
      buffer.writeln('  @override');
      buffer.writeln('  // Implements ${method.name} from $className');
      buffer.writeln('  $returnType $methodName($parameters) {');

      // Handle both Future<T> and T return types
      final effectiveReturnType = returnType.startsWith('Future<')
          ? returnType.substring(7, returnType.length - 1)
          : returnType;

      // Parse wrapper and inner types (e.g., Response<List<MyModel>>)
      final matchOuter = RegExp(r'(\w+)<(.+)>').firstMatch(effectiveReturnType);
      final outerType = matchOuter?.group(1);
      final innerType = matchOuter?.group(2);

      // Parse List<T> inner type
      final listMatch = RegExp(r'List<(\w+)>').firstMatch(innerType ?? '');
      final listItemType = listMatch?.group(1);

      _logger.fine(
          'Return type analysis: effectiveReturnType=$effectiveReturnType, outerType=$outerType, innerType=$innerType, listItemType=$listItemType');

      // Case 1: Wrapped List (e.g., Response<List<MyModel>> or Response<List<String>>)
      if (wrapperType.isNotEmpty &&
          outerType == wrapperType &&
          listItemType != null) {
        _logger.info(
            'Generating code for wrapped List: $wrapperType<List<$listItemType>>');
        buffer.writeln(
            '    // Deserialize JSON into a $wrapperType<List<$listItemType>>');
        buffer.writeln(
            '    return $wrapperType<List<$listItemType>>.$wrapperFromJson(');
        buffer.writeln('      json,');

        // Handle primitive types (no fromJson) vs complex types
        if (isPrimitiveType(listItemType)) {
          buffer.writeln(
              '      (data) => (data as List).cast<$listItemType>().toList(),');
        } else {
          buffer.writeln(
              '      (data) => (data as List).map((e) => $listItemType.fromJson(e as Map<String, dynamic>)).toList(),');
        }
        buffer.writeln('    );');
      }
      // Case 2: Wrapped Model (e.g., Response<MyModel>)
      else if (wrapperType.isNotEmpty &&
          outerType == wrapperType &&
          innerType != null) {
        _logger.info(
            'Generating code for wrapped model: $wrapperType<$innerType>');
        buffer.writeln('    // Deserialize JSON into a $wrapperType<$innerType>');
        buffer.writeln('    return $wrapperType<$innerType>.$wrapperFromJson(');
        buffer.writeln('      json,');
        buffer.writeln(
            '      (data) => $innerType.fromJson(data as Map<String, dynamic>),');
        buffer.writeln('    );');
      }
      // Case 3: Direct List (e.g., List<MyModel> or List<String>)
      else if (effectiveReturnType.startsWith('List<') &&
          listItemType != null) {
        _logger.info('Generating code for List: List<$listItemType>');
        buffer.writeln('    // Deserialize JSON into a List<$listItemType>');
        buffer.writeln('    return (json[\'data\'] as List)');

        // Handle primitive types (no fromJson) vs complex types
        if (isPrimitiveType(listItemType)) {
          buffer.writeln('        .cast<$listItemType>().toList();');
        } else {
          buffer.writeln(
              '        .map((e) => $listItemType.fromJson(e as Map<String, dynamic>))');
          buffer.writeln('        .toList();');
        }
      }
      // Case 4: Direct Model (e.g., MyModel)
      else {
        _logger.info('Generating code for direct model: $effectiveReturnType');
        buffer.writeln('    // Deserialize JSON into a $effectiveReturnType');
        buffer.writeln('    return $effectiveReturnType.fromJson(json);');
      }

      buffer.writeln('  }');
    }

    // Close the implementation class
    buffer.writeln('}');

    _logger.info('Completed generation for $className');
    // Format and return the generated code
    return _formatter.format(buffer.toString());
  }
}

// Factory function to create the builder
Builder generatorFactoryBuilder(BuilderOptions options) => SharedPartBuilder(
  [Json2ModelGenerator()],
  'retrofit',
);