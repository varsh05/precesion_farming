import 'package:flutter/material.dart';
import 'settings_page.dart';
import 'disease_predictor_page.dart';
import 'weather_forcasting.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  Widget _buildDashboardCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.green[100],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.green[800]),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Farming Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDashboardCard("ML Disease Predictor", Icons.biotech, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DiseasePredictorPage(),
                ),
              );
            }),
            _buildDashboardCard("IoT Sensor Values", Icons.sensors, () {
              // Navigate to IoT Sensor Page (to be added later)
            }),
            _buildDashboardCard("Weather Reporter", Icons.cloud, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WeatherForcasting(), // ✅ Connected
                ),
              );
            }),
            _buildDashboardCard("Crop Suggestion", Icons.agriculture, () {
              // Navigate to Crop Suggestion Page (to be added later)
            }),
          ],
        ),
      ),
    );
  }
}
