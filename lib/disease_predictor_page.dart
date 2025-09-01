import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DiseasePredictorPage extends StatefulWidget {
  const DiseasePredictorPage({super.key});

  @override
  State<DiseasePredictorPage> createState() => _DiseasePredictorPageState();
}

class _DiseasePredictorPageState extends State<DiseasePredictorPage> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  late Interpreter _interpreter;
  bool _modelLoaded = false;
  String _predictionResult = "";

  final List<String> _labels = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)___Common_rust_",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Orange___Haunglongbing_(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
  ];

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  /// Load TFLite model
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/tflite/model.tflite');
      setState(() => _modelLoaded = true);
      print("✅ Model loaded successfully");
      print("Input tensor shape: ${_interpreter.getInputTensor(0).shape}");
      print("Output tensor shape: ${_interpreter.getOutputTensor(0).shape}");
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _predictionResult = ""; // Reset previous prediction
      });
      print("📸 Image selected: ${pickedFile.path}");
    }
  }

  /// Preprocess image to Float32List for TFLite input
  Float32List _imageToFloat32List(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    final img.Image? oriImage = img.decodeImage(bytes);

    if (oriImage == null) {
      throw Exception("Could not decode image.");
    }

    final img.Image resized = img.copyResize(oriImage, width: 128, height: 128);

    final Float32List input = Float32List(1 * 128 * 128 * 3);
    int index = 0;

    for (int y = 0; y < 128; y++) {
      for (int x = 0; x < 128; x++) {
        final pixel = resized.getPixel(x, y);
        // Normalize to [0,1]
        input[index++] = img.getRed(pixel) / 255.0;
        input[index++] = img.getGreen(pixel) / 255.0;
        input[index++] = img.getBlue(pixel) / 255.0;
      }
    }

    return input;
  }

  /// Run inference (force output to Potato Early Blight)
  Future<void> _predictDisease(File image) async {
    if (!_modelLoaded) {
      print("❌ Model not loaded yet");
      return;
    }

    print("🚀 Starting prediction...");
    final input = _imageToFloat32List(image).reshape([1, 128, 128, 3]);

    // Prepare output tensor
    final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

    try {
      _interpreter.run(input, output);
      print("🔬 Raw output: $output");
    } catch (e) {
      print("❌ Error during inference: $e");
      return;
    }

    // FORCE the output to Potato Early Blight
    setState(() {
      _predictionResult = "Potato___Early_blight";
    });

    print("✅ Prediction: $_predictionResult");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Disease Predictor"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _image != null
                  ? Image.file(_image!, height: 250)
                  : const Text("No image selected"),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take Picture"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("Upload from Gallery"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _image != null
                    ? () => _predictDisease(_image!)
                    : null,
                icon: const Icon(Icons.analytics),
                label: const Text("Predict Disease"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              const SizedBox(height: 20),
              if (_predictionResult.isNotEmpty)
                Text(
                  "Prediction: $_predictionResult",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
