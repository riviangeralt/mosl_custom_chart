import 'package:flutter/material.dart';
import 'package:flutter_graphic_chart/custom_area_chart.dart';
import 'package:flutter_graphic_chart/custom_bar_chart.dart';
import 'package:flutter_graphic_chart/custom_doughnut_chart.dart';
import 'dart:math';

import 'package:flutter_graphic_chart/custom_line_chart.dart';
import 'package:flutter_graphic_chart/custom_pie_chart.dart';

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
  final MoCustomBarChartController _chartController =
      MoCustomBarChartController();
  bool _showNegativeOnly = false;

  List<ChartData> get chartData => [
    for (int i = 0; i < 5; i++)
      ChartData(
        i + 1,
        i % 7 ==
                6 // keep null every 7th day
            ? null
            : (() {
              // random magnitude between 1,000 and 20,000,000
              double magnitude = 1000 + _rnd.nextDouble() * (20000000 - 1000);
              // For negative-only mode, always return negative values
              if (_showNegativeOnly) {
                return -magnitude;
              }
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
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _chartController.showTooltipAtIndex(0);
                  },
                  child: const Text('Show First'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _chartController.showTooltipAtIndex(chartData.length ~/ 2);
                  },
                  child: const Text('Show Middle'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _chartController.hideTooltip();
                  },
                  child: const Text('Hide Tooltip'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Test button for negative-only data
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showNegativeOnly = !_showNegativeOnly;
                });
              },
              child: Text(
                _showNegativeOnly ? 'Show Mixed Data' : 'Show Negative Only',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height:
                  300, // Decreased from 400 to 300 to show the bottom spacing
              child: MoCustomDoughnutChart<ChartData>(
                // controller: _chartController,
                data: chartData,
                labelMapper: (chartDataType) => chartDataType.day,
                valueMapper: (chartDataType) => chartDataType.value,
                // barWidth: 6.0, // Fixed bar width at 6px
                onSelectionChanged: (int? selectedIndex) {
                  print('Chart selection changed: $selectedIndex');
                },
                tooltipDataFormatter: (ChartData data) {
                  if (data.value == null) {
                    return [
                      TextSpan(
                        text: "Day ${data.day}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const TextSpan(
                        text: "\n",
                        style: TextStyle(fontSize: 14),
                      ),
                      const TextSpan(
                        text: "No data available",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ];
                  }
                  final value = data.value!;
                  final formattedValue =
                      value >= 0
                          ? "+₹${(value / 1000000).toStringAsFixed(1)}M"
                          : "-₹${(value.abs() / 1000000).toStringAsFixed(1)}M";

                  return [
                    TextSpan(
                      text: "Day ${data.day}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const TextSpan(
                      text: "\nP&L: ",
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: formattedValue,
                      style: TextStyle(
                        color:
                            value >= 0
                                ? const Color(0xFF13861D)
                                : const Color(0xFFDF130C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ];
                },
                // yAxisLabelStyleFormatter: (yValue) {
                //   return TextSpan(
                //     text:
                //         yValue >= 0
                //             ? "+₹${(yValue / 1000000).toStringAsFixed(1)}M"
                //             : "-₹${(yValue.abs() / 1000000).toStringAsFixed(1)}M",
                //     style: TextStyle(
                //       color:
                //           yValue >= 0
                //               ? const Color(0xFF13861D)
                //               : const Color(0xFFDF130C),
                //       fontWeight: FontWeight.bold,
                //       fontSize: 12,
                //     ),
                //   );
                // },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
