import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/custom_model.dart';

class ModelSelector extends StatefulWidget {
  final String currentModel;
  final Function(String) onModelSelected;

  const ModelSelector({
    Key? key,
    required this.currentModel,
    required this.onModelSelected,
  }) : super(key: key);

  @override
  _ModelSelectorState createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  bool _isLoading = true;
  List<CustomModel> _availableModels = [];
  
  static const MethodChannel _channel = MethodChannel('com.example.flutter_object_detection/mlkit');
  
  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
  }
  
  Future<void> _loadAvailableModels() async {
    try {
      final List<dynamic>? modelsData = await _channel.invokeMethod('getAvailableModels');
      
      if (modelsData != null) {
        setState(() {
          _availableModels = modelsData.map((data) => 
            CustomModel.fromMap(Map<String, dynamic>.from(data))
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading models: $e');
      setState(() {
        _availableModels = [
          CustomModel(
            name: 'Default ML Kit Model',
            description: 'Built-in ML Kit object detection model',
            isCustom: false,
          ),
          CustomModel(
            name: 'Custom Object Detector',
            description: 'Custom TensorFlow Lite model for object detection',
            isCustom: true,
          ),
        ];
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Model',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableModels.length,
                itemBuilder: (context, index) {
                  final model = _availableModels[index];
                  return RadioListTile<String>(
                    title: Text(model.name),
                    subtitle: Text(model.description),
                    value: model.name,
                    groupValue: widget.currentModel,
                    onChanged: (value) {
                      if (value != null) {
                        widget.onModelSelected(value);
                      }
                    },
                  );
                },
              ),
              
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('ADD CUSTOM MODEL'),
                onPressed: () => _showAddCustomModelDialog(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddCustomModelDialog() {
    // This would show a dialog to add a custom model
    // For this example, we'll just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Model'),
        content: const Text(
          'This feature would allow adding custom TensorFlow Lite models. '
          'In a real implementation, you would upload or select a .tflite file '
          'and provide a label map.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}