import 'package:flutter/material.dart';

void main() => runApp(const DeliveryTimeApp());

class DeliveryTimeApp extends StatelessWidget {
  const DeliveryTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Time Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const PredictionPage(),
    );
  }
}

enum FieldType { decimal, integer, text }

class InputField {
  const InputField(this.key, this.label, this.hint, this.example, this.type);

  final String key;
  final String label;
  final String hint;
  final String example;
  final FieldType type;
}

const sections = <String, List<InputField>>{
  'Trip': [
    InputField('distance_km', 'Distance (km)', '1 to 50', '9', FieldType.decimal),
    InputField('platform_type', 'Platform type', '1, 2, 3 or 4', '3', FieldType.integer),
    InputField('personal_or_business', 'Customer type', 'Business or Personal', 'Business', FieldType.text),
  ],
  'Pickup time': [
    InputField('pickup_weekday', 'Pickup weekday', '1 = Monday ... 7 = Sunday', '3', FieldType.integer),
    InputField('pickup_hour', 'Pickup hour', '0 to 23', '9', FieldType.integer),
  ],
  'Locations': [
    InputField('pickup_lat', 'Pickup latitude', '-1.50 to -1.00', '-1.276574', FieldType.decimal),
    InputField('pickup_long', 'Pickup longitude', '36.50 to 37.10', '36.851365', FieldType.decimal),
    InputField('destination_lat', 'Destination latitude', '-1.50 to -1.00', '-1.252796', FieldType.decimal),
    InputField('destination_long', 'Destination longitude', '36.50 to 37.10', '36.800313', FieldType.decimal),
  ],
  'Rider': [
    InputField('rider_no_of_orders', 'Rider completed orders', '0 to 10000', '2322', FieldType.integer),
    InputField('rider_age_days', "Days since rider's first delivery", '0 to 4000', '966', FieldType.integer),
    InputField('rider_average_rating', 'Rider average rating', '0 to 15.2', '14.4', FieldType.decimal),
  ],
};

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final field in sections.values.expand((fields) => fields))
      field.key: TextEditingController(text: field.example),
  };

  String _message = 'Fill in the order details and tap Predict.';
  bool _isError = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object> _collectInputs() {
    final values = <String, Object>{};
    for (final field in sections.values.expand((fields) => fields)) {
      final raw = _controllers[field.key]!.text.trim();
      if (raw.isEmpty) {
        throw FormatException('${field.label} is required.');
      }
      switch (field.type) {
        case FieldType.integer:
          final value = int.tryParse(raw);
          if (value == null) {
            throw FormatException('${field.label} must be a whole number.');
          }
          values[field.key] = value;
        case FieldType.decimal:
          final value = double.tryParse(raw);
          if (value == null) {
            throw FormatException('${field.label} must be a number.');
          }
          values[field.key] = value;
        case FieldType.text:
          final lower = raw.toLowerCase();
          if (lower != 'business' && lower != 'personal') {
            throw FormatException('${field.label} must be Business or Personal.');
          }
          values[field.key] = lower == 'business' ? 'Business' : 'Personal';
      }
    }
    return values;
  }

  void _predict() {
    try {
      _collectInputs();
      setState(() {
        _isError = false;
        _message = 'Inputs look good. Connecting to the API comes next.';
      });
    } on FormatException catch (error) {
      setState(() {
        _isError = true;
        _message = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nairobi Delivery Time')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Estimate how long a motorbike delivery will take from pick-up to arrival.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in sections.entries) _buildSection(entry.key, entry.value),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: FilledButton(onPressed: _predict, child: const Text('Predict')),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isError ? colors.errorContainer : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _message,
                style: TextStyle(
                  fontSize: 16,
                  color: _isError ? colors.onErrorContainer : colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<InputField> fields) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final field in fields) ...[
              _buildField(field),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(InputField field) {
    return TextField(
      controller: _controllers[field.key],
      keyboardType: field.type == FieldType.text
          ? TextInputType.text
          : TextInputType.numberWithOptions(signed: true, decimal: field.type == FieldType.decimal),
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}