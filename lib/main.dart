import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_graphic_chart/custom_multi_series_bar_chart.dart';

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

// Define ChartData class for individual data points
class DataPoint {
  final int day;
  final num? value;
  DataPoint(this.day, this.value);
}

// Assuming MoCustomBarChart is defined in a separate file
// Include the MoCustomBarChart code from the previous response here
// For brevity, it's not repeated in this example

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Random _rnd = Random();
  final MoCustomMultiSeriesBarChartController _chartController =
      MoCustomMultiSeriesBarChartController();
  bool _showNegativeOnly = false;
  bool _showPositiveOnly = false;

  // Generate data for two series
  List<ChartData<DataPoint>> get chartSeries => [
    ChartData<DataPoint>(
      seriesName: 'Sales',
      barColorMapper: (yValue) {
        if (yValue == null) return Colors.grey;
        return Colors.blue;
      },
      data: [
        for (int i = 0; i < 6; i++)
          DataPoint(
            i + 1,
            i % 7 ==
                    6 // Null every 7th day
                ? null
                : (() {
                  double magnitude =
                      1000 + _rnd.nextDouble() * (20000000 - 1000);
                  return _showNegativeOnly
                      ? -magnitude
                      : _showPositiveOnly
                      ? magnitude
                      : (_rnd.nextBool() ? magnitude : -magnitude);
                })(),
          ),
      ],
    ),
    ChartData<DataPoint>(
      seriesName: 'Expenses',
      barColorMapper: (yValue) {
        if (yValue == null) return Colors.grey;
        return Colors.red;
      },
      data: [
        for (int i = 0; i < 6; i++)
          DataPoint(
            i + 1,
            i % 7 ==
                    6 // Null every 7th day
                ? null
                : (() {
                  double magnitude =
                      1000 + _rnd.nextDouble() * (15000000 - 1000);
                  return _showNegativeOnly
                      ? -magnitude
                      : _showPositiveOnly
                      ? magnitude
                      : (_rnd.nextBool() ? magnitude : -magnitude);
                })(),
          ),
      ],
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
                    _chartController.showTooltipAtIndex(
                      chartSeries[0].data.length ~/ 2,
                    );
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
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showPositiveOnly = !_showPositiveOnly;
                });
              },
              child: Text(
                _showPositiveOnly ? 'Show Mixed Data' : 'Show Positive Only',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: MoCustomMultiSeriesBarChart<DataPoint>(
                controller: _chartController,
                series: chartSeries,
                maxXLabels: 4,
                xValueMapper: (data) => data.day,
                yValueMapper: (data) => data.value,
                onSelectionChanged: (int? selectedIndex) {
                  print('Chart selection changed: $selectedIndex');
                },
                onBarTap: (DataPoint data, int seriesIndex) {
                  print(
                    'Bar tapped: Day ${data.day}, Series $seriesIndex, Value ${data.value}',
                  );
                },
                tooltipDataFormatter: (DataPoint data, int seriesIndex) {
                  if (data.value == null) {
                    return [
                      TextSpan(
                        text:
                            "${chartSeries[seriesIndex].seriesName} - Day ${data.day}",
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
                      text:
                          "${chartSeries[seriesIndex].seriesName} - Day ${data.day}",
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
                yAxisLabelStyleFormatter: (yValue) {
                  return TextSpan(
                    text:
                        yValue >= 0
                            ? "+₹${(yValue / 1000000).toStringAsFixed(1)}M"
                            : "-₹${(yValue.abs() / 1000000).toStringAsFixed(1)}M",
                    style: TextStyle(
                      color:
                          yValue >= 0
                              ? const Color(0xFF13861D)
                              : const Color(0xFFDF130C),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
                barWidth: 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
