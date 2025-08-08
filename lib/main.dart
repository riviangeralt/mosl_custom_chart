import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_graphic_chart/custom_bar_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Bar Chart Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Custom Bar Chart'),
    );
  }
}

class ChartData {
  final int day;
  final num? value;
  ChartData(this.day, this.value);
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<ChartData> get chartData => [
    for (int i = 0; i < 31; i++)
      ChartData(
        i + 1,
        i % 7 ==
                6 // Set value to null for every 7th day (e.g., Day 7, 14, 21, 28)
            ? null
            : i % 5 == 0
            ? 5000
            : (i % 2 == 0 ? 20000000 : -20000000) * (i % 3 + 1) / 3,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Profit/Loss Chart',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height:
                  480, // Increased from 400 to 480 to show the bottom spacing
              child: CustomBarChart<ChartData>(
                data: chartData,
                xValueMapper: (chartDataType) => chartDataType.day,
                yValueMapper: (chartDataType) => chartDataType.value,
                onSelectionChanged: (int? selectedIndex) {
                  print('Chart selection changed: $selectedIndex');
                },
                xAxisLabelFormatter: (xValue) {
                  return "Day $xValue";
                },
                yAxisLabelFormatter: (yValue) {
                  return yValue == null
                      ? "No data"
                      : yValue >= 0
                          ? "₹${(yValue / 1000000).toStringAsFixed(1)}M"
                          : "-₹${(yValue.abs() / 1000000).toStringAsFixed(1)}M";
                },
                tooltipDataFormatter: (ChartData data) {
                  if (data.value == null) {
                    return "Day ${data.day}\nNo data available";
                  }
                  final value = data.value!;
                  final formattedValue =
                      value >= 0
                          ? "+₹${(value / 1000000).toStringAsFixed(1)}M"
                          : "-₹${(value.abs() / 1000000).toStringAsFixed(1)}M";
                  return "Day ${data.day}\nP&L: $formattedValue\nStatus: ${value >= 0 ? 'Profit' : 'Loss'}";
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
