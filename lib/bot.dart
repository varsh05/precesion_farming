import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class BotScreen extends StatefulWidget {
  const BotScreen({super.key});

  @override
  State<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends State<BotScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isTyping = false;
  final FlutterTts _flutterTts = FlutterTts();

  // Card interactions
  bool _isNutritionExpanded = false;
  bool _isExerciseExpanded = false;
  late AnimationController _nutritionController;
  late AnimationController _exerciseController;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();

    _nutritionController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _exerciseController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _nutritionController.dispose();
    _exerciseController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  void _initializeSpeech() async {
    await _speech.initialize();
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS error: $msg");
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> sendMessage(String message) async {
    setState(() {
      messages.add({"role": "user", "message": message});
      _isTyping = true;
    });

    _scrollToBottom();

    String response = await getAIResponse(message);

    setState(() {
      messages.add({"role": "bot", "message": response});
      _isTyping = false;
    });

    _scrollToBottom();
    await _flutterTts.speak(response);
  }

  String _getSystemPrompt(String userMessage) {
    List<String> greetings = [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
    ];
    List<String> casual = [
      'how are you',
      'what\'s up',
      'sup',
      'thanks',
      'thank you',
      'ok',
      'okay',
    ];

    String lowerMessage = userMessage.toLowerCase().trim();

    if (greetings.any(
      (greeting) =>
          lowerMessage == greeting || lowerMessage.startsWith(greeting),
    )) {
      return '''You are an agricultural and farming assistant. Respond with a brief, friendly greeting (1-2 sentences) and mention that you're here to help with farming questions.
      
      USER MESSAGE: $userMessage''';
    }

    if (casual.any((word) => lowerMessage.contains(word)) &&
        lowerMessage.length < 20) {
      return '''You are an agricultural and farming assistant. Respond briefly and naturally (1-2 sentences). Ask how you can help with their farming needs.
      
      USER MESSAGE: $userMessage''';
    }

    return '''You are a specialized agricultural and farming assistant for India. Your expertise covers a wide range of topics, including:
    - **Crop Management:** Best practices for sowing, irrigation, and harvesting.
    - **Pest and Disease Control:** Identification and management of common plant diseases and pests.
    - **Soil Health:** Advice on soil types, nutrient deficiencies, and fertilization.
    - **Weather and Climate:** How weather patterns affect crops, with an emphasis on Indian climates.
    - **Modern Farming Techniques:** Information on new technologies and sustainable practices.
    - **Government Schemes:** Brief details on relevant government programs for farmers in India.
    - **Market Information:** General advice on crop prices and market trends (without real-time data).
    
    Be concise, precise, and helpful. Always emphasize consulting with local agricultural experts or government extension services for official advice. Do not provide medical, financial, or personal advice. Stick strictly to agriculture and farming topics.

    USER QUESTION: $userMessage

    Provide a helpful, precise, and practical response.''';
  }

  Future<String> getAIResponse(String userMessage) async {
    try {
      final String? apiKey = dotenv.env['GEMINI_API_KEY'];
      final String? apiUrl = dotenv.env['GEMINI_API_URL'];

      if (apiKey == null) {
        return 'API key not found. Please check your .env file.';
      }

      final String endpoint =
          '$apiUrl/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _getSystemPrompt(userMessage)},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 800,
            'topP': 0.8,
            'topK': 40,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('API Response: $data');

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null) {
          return data['candidates'][0]['content']['parts'][0]['text'] ??
              'No response text found';
        }
        return 'Invalid response format from API';
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      debugPrint('Error in getAIResponse: $e');
      return 'An error occurred. Please check your internet connection and try again.';
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              setState(() {
                _controller.text = result.recognizedWords;
              });
              sendMessage(result.recognizedWords);
            }
          },
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _stopTtsAndClearInput() async {
    await _flutterTts.stop();
    _controller.clear();
  }

  Widget _buildEducationContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Farming Guide & Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Crop Guide Card
          GestureDetector(
            onTap: () {
              setState(() {
                _isNutritionExpanded = !_isNutritionExpanded;
              });
              if (_isNutritionExpanded) {
                _nutritionController.forward();
              } else {
                _nutritionController.reverse();
              }
            },
            child: AnimatedBuilder(
              animation: _nutritionController,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_nutritionController.value * 3.14159),
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green[400]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _nutritionController.value > 0.5
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: const Center(
                              child: Text(
                                '• Crop Rotation for soil health\n\n'
                                '• Use organic fertilizers & compost\n\n'
                                '• Water early in the morning or late evening\n\n'
                                '• Monitor for pests & diseases regularly',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Essential\nFarming Tips',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Pest & Disease Card
          GestureDetector(
            onTap: () {
              setState(() {
                _isExerciseExpanded = !_isExerciseExpanded;
              });
              if (_isExerciseExpanded) {
                _exerciseController.forward();
              } else {
                _exerciseController.reverse();
              }
            },
            child: AnimatedBuilder(
              animation: _exerciseController,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_exerciseController.value * 3.14159),
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green[400]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _exerciseController.value > 0.5
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(3.14159),
                            child: const Center(
                              child: Text(
                                '• Use neem oil for natural pest control\n\n'
                                '• Remove infected leaves to prevent spread\n\n'
                                '• Ensure proper plant spacing for air circulation\n\n'
                                '• Consult a local expert for severe infestations',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Pest & Disease\nManagement',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[300]!, width: 1),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Always consult a local agricultural expert or government extension officer for official advice.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Typing...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Agri-Assistant',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.agriculture,
                            size: 50,
                            color: Colors.green[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ask about crops, soil, pests,\nor any farming topic!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Try: "What is the best fertilizer for rice?"',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTypingIndicator(),
                        );
                      }

                      final message = messages[index];
                      bool isUser = message["role"] == "user";

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.green[100] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUser
                                  ? Colors.green[300]!
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message["message"]!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Ask about farming...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) {
                          if (text.isNotEmpty) {
                            sendMessage(text);
                            _controller.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.green[800]),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          sendMessage(_controller.text);
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_off,
                        color: _isListening
                            ? Colors.red[700]
                            : Colors.grey[700],
                      ),
                      onPressed: () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.stop, color: Colors.grey[700]),
                      onPressed: _stopTtsAndClearInput,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
