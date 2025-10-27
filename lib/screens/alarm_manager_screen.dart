import 'package:flutter/material.dart';
import '../services/alarm_manager.dart';
import 'alarm_screen.dart';

class AlarmManagerScreen extends StatefulWidget {
  const AlarmManagerScreen({super.key});

  @override
  State<AlarmManagerScreen> createState() => _AlarmManagerScreenState();
}

class _AlarmManagerScreenState extends State<AlarmManagerScreen> {
  final AlarmManager _alarmManager = AlarmManager();
  List<Alarm> _alarms = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _alarmManager.initialize();
    setState(() {
      _alarms = _alarmManager.getAlarms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake Me Up'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alarm_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alarms set',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _alarms.length,
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(alarm.name),
                    subtitle: Text(
                      'Radius: ${alarm.radius.round()}m',
                    ),
                    trailing: Switch(
                      value: alarm.isActive,
                      onChanged: (value) async {
                        alarm.isActive = value;
                        await _alarmManager.updateAlarm(alarm);
                        setState(() {});
                      },
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/alarm',
                        arguments: alarm,
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/alarm');
        },
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add),
      ),
    );
  }
} 