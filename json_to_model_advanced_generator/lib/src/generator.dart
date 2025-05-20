import 'dart:async';
import 'package:build/build.dart';
import 'package:logging/logging.dart'; // For logging
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';
import 'package:json_to_model_advanced/json_to_model_advanced.dart';

class Json2ModelGenerator extends GeneratorForAnnotation<JsonToModel> {
  final _formatter = DartFormatter();
  final _logger = Logger('Json2ModelGenerator');

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    _logger.info('Processing element: ${element.name}');

    if (element is! ClassElement) {
      _logger
          .warning('Element ${element.name} is not a ClassElement, skipping.');
      return '';
    }

    final classElement = element as ClassElement;
    final className = classElement.name;
    final implClassName = '_$className';

    _logger.info('Generating implementation for class: $className');

    final wrapperType = annotation.read('wrapperType').stringValue ?? null;
    final wrapperFromJson =
        annotation.read('wrapperFromJson').stringValue ?? 'fromJson';
    _logger.info(
        'Annotation config: wrapperType=$wrapperType, wrapperFromJson=$wrapperFromJson');

    final buffer = StringBuffer();
    buffer.writeln('class $implClassName implements $className {');

    for (final method in classElement.methods) {
      if (!method.isAbstract) {
        _logger.fine('Skipping non-abstract method: ${method.name}');
        continue;
      }

      _logger.info(
          'Processing method: ${method.name} with return type: ${method.returnType}');

      final returnType =
          method.returnType.getDisplayString(withNullability: false);
      final methodName = method.name;
      final parameters = method.parameters.map((param) {
        final type = param.type.getDisplayString(withNullability: false);
        return '$type ${param.name}';
      }).join(', ');

      buffer.writeln('  @override');
      buffer.writeln('  $returnType $methodName($parameters) {');

      // Handle both Future<T> and T return types
      final effectiveReturnType = returnType.startsWith('Future<')
          ? returnType.substring(7, returnType.length - 1) // Strip Future<...>
          : returnType;

      final matchOuter = RegExp(r'(\w+)<(.+)>').firstMatch(effectiveReturnType);
      final outerType = matchOuter?.group(1);
      final innerType = matchOuter?.group(2);

      final listMatch = RegExp(r'List<(\w+)>').firstMatch(innerType ?? '');
      final listItemType = listMatch?.group(1);

      _logger.fine(
          'Return type analysis: effectiveReturnType=$effectiveReturnType, outerType=$outerType, innerType=$innerType, listItemType=$listItemType');
      _logger.fine('effectiveReturnType ${effectiveReturnType}');
      _logger.fine('listItemType ${listItemType}');
      _logger.fine('wrapperType ${wrapperType}');
      _logger.fine('outerType ${outerType}');
      _logger.fine('innerType ${innerType}');
      _logger.fine('--------------');
      if (wrapperType != null &&
          outerType == wrapperType &&
          listItemType != null) {
        _logger.info(
            '1 Generating code for wrapped List: $wrapperType<List<$listItemType>>');
        buffer.writeln(
            '    return $wrapperType<List<$listItemType>>.$wrapperFromJson(');
        buffer.writeln('      json,');
        buffer.writeln(
            '      (data) => (data as List).map((e) => $listItemType.fromJson(e as Map<String, dynamic>)).toList(),');
        buffer.writeln('    );');
      } else if (wrapperType != null &&
          outerType == wrapperType &&
          innerType != null) {
        _logger.info(
            '2 Generating code for wrapped model: $wrapperType<$innerType>');
        buffer.writeln('    return $wrapperType<$innerType>.$wrapperFromJson(');
        buffer.writeln('      json,');
        buffer.writeln(
            '      (data) => $innerType.fromJson(data as Map<String, dynamic>),');
        buffer.writeln('    );');
      } else if (effectiveReturnType.startsWith('List<') &&
          listItemType != null) {
        _logger.info('3 Generating code for List: List<$listItemType>');
        buffer.writeln('    return (json[\'data\'] as List)');
        buffer.writeln(
            '        .map((e) => $listItemType.fromJson(e as Map<String, dynamic>))');
        buffer.writeln('        .toList();');
      } else {
        _logger
            .info('4 Generating code for direct model: $effectiveReturnType');
        buffer.writeln('    return $effectiveReturnType.fromJson(json);');
      }

      buffer.writeln('  }');
    }

    buffer.writeln('}');

    _logger.info('Completed generation for $className');
    return _formatter.format(buffer.toString());
  }
}

Builder generatorFactoryBuilder(BuilderOptions options) => SharedPartBuilder(
      [Json2ModelGenerator()],
      'retrofit',
    );
