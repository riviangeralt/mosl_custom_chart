import 'package:flutter/material.dart';
import 'package:flutter_graphic_chart/custom_bar_chart.dart';
import 'dart:math';

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
 final Random _rnd = Random();

List<ChartData> get chartData => [
  for (int i = 0; i < 10; i++)
    ChartData(
      i + 1,
      i % 7 == 6 // keep null every 7th day
          ? null
          : (() {
              // random magnitude between 1,000 and 20,000,000
              double magnitude = 1000 + _rnd.nextDouble() * (20000000 - 1000);
              // randomly decide positive or negative
              return _rnd.nextBool() ? magnitude : -magnitude;
            })(),
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
                  300, // Decreased from 400 to 300 to show the bottom spacing
              child: MoCustomBarChart<ChartData>(
                data: chartData,
                xValueMapper: (chartDataType) => chartDataType.day,
                yValueMapper: (chartDataType) => chartDataType.value,
                barWidth: 6.0, // Fixed bar width at 6px
                onSelectionChanged: (int? selectedIndex) {
                  print('Chart selection changed: $selectedIndex');
                },
                xAxisLabelFormatter: (xValue) {
                  return "Day $xValue";
                },
                yAxisLabelFormatter: (yValue) {
                  return yValue >= 0
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
