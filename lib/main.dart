import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import 'detection_camera.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

try {
 cameras = await availableCameras();
} on CameraException catch (e) {
 debugPrint('Error initializing camera: $e');
}

runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({Key? key}) : super(key: key);

@override
Widget build(BuildContext context) {
 return MaterialApp(
   title: 'Flutter Object Detection',
   theme: ThemeData(
     primarySwatch: Colors.blue,
     visualDensity: VisualDensity.adaptivePlatformDensity,
     brightness: Brightness.light,
   ),
   darkTheme: ThemeData(
     primarySwatch: Colors.blue,
     visualDensity: VisualDensity.adaptivePlatformDensity,
     brightness: Brightness.dark,
   ),
   themeMode: ThemeMode.system,
   home: const HomePage(),
 );
}
}

class HomePage extends StatefulWidget {
const HomePage({Key? key}) : super(key: key);

@override
_HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
bool _debugMode = false;
bool _trackingEnabled = true;
String _currentModel = 'Default ML Kit Model';

@override
Widget build(BuildContext context) {
 return Scaffold(
   appBar: AppBar(
     title: const Text('Object Detection'),
     actions: [
       // Model selector button
       IconButton(
         icon: const Icon(Icons.model_training),
         onPressed: () => _showModelSelector(),
         tooltip: 'Select Model',
       ),
       // Debug mode toggle
       IconButton(
         icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
         onPressed: () => setState(() => _debugMode = !_debugMode),
         tooltip: 'Debug Mode',
       ),
       // Tracking toggle
       IconButton(
         icon: Icon(_trackingEnabled ? Icons.track_changes : Icons.track_changes_outlined),
         onPressed: () => setState(() => _trackingEnabled = !_trackingEnabled),
         tooltip: 'Toggle Tracking',
       ),
     ],
   ),
   body: cameras.isEmpty
       ? const Center(child: Text('No camera available'))
       : DetectionCamera(
           cameras: cameras,
           debugMode: _debugMode,
           trackingEnabled: _trackingEnabled,
           currentModel: _currentModel,
         ),
 );
}

void _showModelSelector() async {
 final result = await showDialog<String>(
   context: context,
   builder: (context) => ModelSelectorDialog(currentModel: _currentModel),
 );
 
 if (result != null) {
   setState(() => _currentModel = result);
 }
}
}

class ModelSelectorDialog extends StatefulWidget {
final String currentModel;

const ModelSelectorDialog({
 Key? key,
 required this.currentModel,
}) : super(key: key);

@override
_ModelSelectorDialogState createState() => _ModelSelectorDialogState();
}

class _ModelSelectorDialogState extends State<ModelSelectorDialog> {
late String _selectedModel;
bool _isLoading = true;
List<String> _availableModels = [];

static const MethodChannel _channel = MethodChannel('com.example.flutter_object_detection/mlkit');

@override
void initState() {
 super.initState();
 _selectedModel = widget.currentModel;
 _loadAvailableModels();
}

Future<void> _loadAvailableModels() async {
 try {
   final List<dynamic>? models = await _channel.invokeMethod('getAvailableModels');
   
   if (models != null) {
     setState(() {
       _availableModels = List<String>.from(models);
       _isLoading = false;
     });
   }
 } catch (e) {
   debugPrint('Error loading models: $e');
   setState(() {
     _availableModels = ['Default ML Kit Model', 'Custom Object Detector'];
     _isLoading = false;
   });
 }
}

@override
Widget build(BuildContext context) {
 return AlertDialog(
   title: const Text('Select Model'),
   content: _isLoading
       ? const SizedBox(
           height: 100,
           child: Center(child: CircularProgressIndicator()),
         )
       : SizedBox(
           width: double.maxFinite,
           child: ListView.builder(
             shrinkWrap: true,
             itemCount: _availableModels.length,
             itemBuilder: (context, index) {
               final model = _availableModels[index];
               return RadioListTile<String>(
                 title: Text(model),
                 value: model,
                 groupValue: _selectedModel,
                 onChanged: (value) {
                   setState(() => _selectedModel = value!);
                 },
               );
             },
           ),
         ),
   actions: [
     TextButton(
       onPressed: () => Navigator.of(context).pop(),
       child: const Text('CANCEL'),
     ),
     TextButton(
       onPressed: () => Navigator.of(context).pop(_selectedModel),
       child: const Text('SELECT'),
     ),
   ],
 );
}
}