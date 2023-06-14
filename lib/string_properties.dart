library string_properties;

import 'package:flutter/widgets.dart';

const String _listSeparator = "<|";
const String _listReplaceSeparator = "<-|";
const String _propertySeparator = "|>";
const String _propertyReplaceSeparator = "|->";
const String _propertyMapperSeparator = "=>";
const String _propertyMapperReplaceSeparator = "==>";
const String _mapReferenceSeparator = "|=";
const String _mapReferenceReplaceSeparator = "||=";

abstract class ElementPropertyHolder {
  Map<ElementProperty<dynamic>, dynamic>? _properties;

  /// Returns a list of properties that this element has. This will be used to save and load as keys.
  List<ElementProperty> buildProperties();

  /// Returns the data that should be saved for this element. This is automatically called. Use get/setProperty to change values.
  String getPropertyData();

  /// Sets the data that should be saved for this element. This is automatically called. Use get/setProperty to change values.
  void setPropertyData(String data);

  Map<ElementProperty<dynamic>, dynamic> _getProperties() {
    if (_properties == null) {
      _properties = {for (var e in buildProperties()) e: e.defaultValue};
      _deserialize(getPropertyData());
    }

    return _properties!;
  }

  T getProperty<T>(ElementProperty<T> property) =>
      _getProperties().containsKey(property)
          ? _getProperties()[property]
          : throw Exception("Property $property not found");

  void setProperty<T>(ElementProperty<T> property, T value) {
    _getProperties().containsKey(property)
        ? _getProperties()[property] = value
        : throw Exception("Property $property not found");
    _save();
  }

  void _save() => setPropertyData(_serialize());

  String _serialize() {
    Map<ElementProperty<dynamic>, dynamic> properties = _getProperties();
    String serialized = "";
    for (final MapEntry<ElementProperty<dynamic>, dynamic> property
        in properties.entries) {
      serialized += property.key.name
              .replaceAll(
                  _propertyMapperSeparator, _propertyMapperReplaceSeparator)
              .replaceAll(_propertySeparator, _propertyReplaceSeparator) +
          _propertyMapperSeparator +
          property.key
              .serialize(property.value)
              .replaceAll(
                  _propertyMapperSeparator, _propertyMapperReplaceSeparator)
              .replaceAll(_propertySeparator, _propertyReplaceSeparator) +
          _propertySeparator;
    }
    return serialized;
  }

  void _deserialize(String serialized) {
    Map<ElementProperty<dynamic>, dynamic> properties = _getProperties();
    List<String> split = serialized.split(_propertySeparator);
    for (final String property in split) {
      List<String> splitProperty = property.split(_propertyMapperSeparator);
      if (splitProperty.length == 2) {
        for (final property in properties.entries) {
          if (property.key.name == splitProperty[0]) {
            property.key.deserialize(splitProperty[1]);
            break;
          }
        }
      }
    }
  }
}

abstract class ElementType<T> {
  String serialize(T value);

  T deserialize(String value);
}

abstract class ElementProperty<T> extends ElementType<T> {
  final String name;
  final String description;
  final T defaultValue;
  final IconData icon;

  ElementProperty({
    required this.name,
    required this.icon,
    required this.description,
    required this.defaultValue,
  });
}

class StringProperty extends ElementProperty<String> {
  final int? maxLength;
  final bool autoTrim;

  StringProperty(
      {required super.name,
      required super.icon,
      required super.description,
      required super.defaultValue,
      this.autoTrim = true,
      this.maxLength});

  String _trim(String s) => _autoTrim(_trimLength(_autoTrim(s)));

  String _trimLength(String s) => maxLength != null && s.length > maxLength!
      ? s.substring(0, maxLength!)
      : s;

  String _autoTrim(String s) => autoTrim ? s.trim() : s;

  @override
  String deserialize(String value) => _trim(value);

  @override
  String serialize(String value) => _trim(value);
}

class IntegerProperty extends ElementProperty<int> {
  final int? min;
  final int? max;

  IntegerProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    this.min,
    this.max,
  });

  int _clamp(int value) => min != null && value < min!
      ? min!
      : max != null && value > max!
          ? max!
          : value;

  @override
  int deserialize(String value) => _clamp(int.tryParse(value) ?? defaultValue);

  @override
  String serialize(int value) => _clamp(value).toString();
}

class DoubleProperty extends ElementProperty<double> {
  final double? min;
  final double? max;

  DoubleProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    this.min,
    this.max,
  });

  double _clamp(double value) => min != null && value < min!
      ? min!
      : max != null && value > max!
          ? max!
          : value;

  @override
  double deserialize(String value) =>
      _clamp(double.tryParse(value) ?? defaultValue);

  @override
  String serialize(double value) => _clamp(value).toString();
}

class BooleanProperty extends ElementProperty<bool> {
  BooleanProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
  });

  @override
  bool deserialize(String value) =>
      value == "t" ||
      value == "true" ||
      value == "1" ||
      value == "yes" ||
      value == "y" ||
      value == "on" ||
      value == "enabled" ||
      value == "enable";

  @override
  String serialize(bool value) => value ? "t" : "f";
}

class EnumProperty<T> extends ElementProperty<T> {
  final List<T> values;

  EnumProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    required this.values,
  });

  @override
  T deserialize(String value) => values.firstWhere(
        (element) => element.toString().split(".").last == value,
        orElse: () => defaultValue,
      );

  @override
  String serialize(T value) => value.toString().split(".").last;
}

class ListProperty<T> extends ElementProperty<List<T>> {
  final ElementType<T> type;

  ListProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    required this.type,
  });

  @override
  List<T> deserialize(String value) =>
      value.split(_listSeparator).map((e) => type.deserialize(e)).toList();

  @override
  String serialize(List<T> value) => value
      .map((e) =>
          type.serialize(e).replaceAll(_listSeparator, _listReplaceSeparator))
      .join(_listSeparator);
}

class SetProperty<T> extends ElementProperty<Set<T>> {
  final ElementType<T> type;

  SetProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    required this.type,
  });

  @override
  Set<T> deserialize(String value) =>
      value.split(_listSeparator).map((e) => type.deserialize(e)).toSet();

  @override
  String serialize(Set<T> value) => value
      .map((e) =>
          type.serialize(e).replaceAll(_listSeparator, _listReplaceSeparator))
      .join(_listSeparator);
}

class MapProperty<K, V> extends ElementProperty<Map<K, V>> {
  final ElementType<K> keyType;
  final ElementType<V> valueType;

  MapProperty({
    required super.name,
    required super.icon,
    required super.description,
    required super.defaultValue,
    required this.keyType,
    required this.valueType,
  });

  @override
  Map<K, V> deserialize(String value) {
    final map = <K, V>{};
    value.split(_listSeparator).forEach((element) {
      final split = element.split(_mapReferenceSeparator);
      map[keyType.deserialize(split[0])] = valueType.deserialize(split[1]);
    });
    return map;
  }

  @override
  String serialize(Map<K, V> value) => value.entries
      .map((e) =>
          "${keyType.serialize(e.key).replaceAll(_mapReferenceSeparator, _mapReferenceReplaceSeparator)}$_mapReferenceSeparator${valueType.serialize(e.value).replaceAll(_mapReferenceSeparator, _mapReferenceReplaceSeparator)}")
      .map((e) => e.replaceAll(_listSeparator, _listReplaceSeparator))
      .join(_listSeparator);
}
