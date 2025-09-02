import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart'; // for formatting sunrise/sunset times

class WeatherForcasting extends StatefulWidget {
  const WeatherForcasting({super.key});

  @override
  State<WeatherForcasting> createState() => _WeatherForecastingState();
}

class _WeatherForecastingState extends State<WeatherForcasting> {
  Map<String, dynamic>? weatherData;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      setState(() {
        errorMessage =
            "Location permissions are permanently denied. Please enable them from settings.";
        isLoading = false;
      });
      return;
    }

    if (status.isGranted) {
      _loadWeather();
    } else {
      setState(() {
        errorMessage = "Location permission denied.";
        isLoading = false;
      });
    }
  }

  Future<void> _loadWeather() async {
    try {
      Position position = await _getCurrentLocation();
      var data = await _fetchWeather(position.latitude, position.longitude);
      setState(() {
        weatherData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<Map<String, dynamic>> _fetchWeather(double lat, double lon) async {
    const apiKey = "fa11a62f52b02732da48cff90737914b"; // Your API Key
    final url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load weather data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Weather Forecasting"),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.blue.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : errorMessage.isNotEmpty
              ? Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                )
              : weatherData == null
              ? const Text(
                  "No weather data available",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                )
              : _buildWeatherCard(),
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final city = weatherData!["name"];
    final temp = weatherData!["main"]["temp"].toString();
    final condition = weatherData!["weather"][0]["main"];
    final iconCode = weatherData!["weather"][0]["icon"];

    final feelsLike = weatherData!["main"]["feels_like"].toString();
    final humidity = weatherData!["main"]["humidity"].toString();
    final pressure = weatherData!["main"]["pressure"].toString();
    final windSpeed = weatherData!["wind"]["speed"].toString();
    final minTemp = weatherData!["main"]["temp_min"].toString();
    final maxTemp = weatherData!["main"]["temp_max"].toString();

    final sunrise = DateTime.fromMillisecondsSinceEpoch(
      weatherData!["sys"]["sunrise"] * 1000,
      isUtc: true,
    );
    final sunset = DateTime.fromMillisecondsSinceEpoch(
      weatherData!["sys"]["sunset"] * 1000,
      isUtc: true,
    );

    return SingleChildScrollView(
      child: Card(
        color: Colors.white.withOpacity(0.9),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                city,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Image.network(
                "https://openweathermap.org/img/wn/$iconCode@2x.png",
                width: 100,
                height: 100,
              ),
              Text(
                "$temp°C",
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              Text(
                condition,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const Divider(height: 30, thickness: 1),

              // Extra weather details
              _infoRow(Icons.thermostat, "Feels Like", "$feelsLike°C"),
              _infoRow(Icons.arrow_downward, "Min Temp", "$minTemp°C"),
              _infoRow(Icons.arrow_upward, "Max Temp", "$maxTemp°C"),
              _infoRow(Icons.water_drop, "Humidity", "$humidity%"),
              _infoRow(Icons.speed, "Pressure", "$pressure hPa"),
              _infoRow(Icons.air, "Wind Speed", "$windSpeed m/s"),
              _infoRow(
                Icons.wb_sunny,
                "Sunrise",
                DateFormat("hh:mm a").format(sunrise.toLocal()),
              ),
              _infoRow(
                Icons.nightlight_round,
                "Sunset",
                DateFormat("hh:mm a").format(sunset.toLocal()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
