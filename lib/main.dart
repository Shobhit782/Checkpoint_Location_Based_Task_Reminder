import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'services/location_service.dart';
import 'widgets/location_picker.dart';
import 'models/lat_lng.dart';
import 'services/place_recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/introduction_screens.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().init();

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Force first launch for testing
  await prefs.setBool('isFirstLaunch', true);
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

class TaskColors {
  static final Map<String, Color> categoryColors = {
    'Personal': const Color(0xFF6C63FF), // Indigo
    'Home Maintenance': const Color(0xFF4CAF50), // Green
    'Fitness/Health': const Color(0xFFE91E63), // Pink
    'Social': const Color(0xFFFF9800), // Orange
    'Finance': const Color(0xFF2196F3), // Blue
    'Education': const Color(0xFF9C27B0), // Purple
    'Shopping': const Color(0xFF009688), // Teal
    'Work': const Color(0xFFF44336), // Red
    'Unknown': const Color(0xFF9E9E9E), // Grey
  };

  static Color getColorForCategory(String category) {
    return categoryColors[category] ?? categoryColors['Unknown']!;
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones(); // Initialize time zones

    await AwesomeNotifications().initialize(
      null, // No default icon
      [
        NotificationChannel(
          channelKey: 'reminder_channel_id',
          channelName: 'Reminders',
          channelDescription: 'Notifications for assignment reminders',
          defaultColor: const Color(0xFF6C63FF),
          ledColor: const Color(0xFF6C63FF),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
        NotificationChannel(
          channelKey: 'reminder_location_channel_id',
          channelName: 'Location Reminders',
          channelDescription: 'Notifications for nearby location reminders',
          defaultColor: const Color(0xFF6C63FF),
          ledColor: const Color(0xFF6C63FF),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
      ],
    );

    // Request notification permissions
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<bool> requestNotificationPermissions() async {
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  Future<void> scheduleNotification(
    String title,
    DateTime scheduledTime,
  ) async {
    try {
      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        print('Cannot schedule notification for past time');
        return;
      }

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'reminder_channel_id',
          title: title,
          body: "Your assignment is due!",
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          criticalAlert: true,
          displayOnForeground: true,
          displayOnBackground: true,
          backgroundColor: const Color(0xFF6C63FF),
        ),
        schedule: NotificationCalendar(
          year: scheduledTime.year,
          month: scheduledTime.month,
          day: scheduledTime.day,
          hour: scheduledTime.hour,
          minute: scheduledTime.minute,
          second: 0,
          millisecond: 0,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      print(
        'Notification scheduled successfully for ${scheduledTime.toString()}',
      );
    } catch (e) {
      print('Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  Future<void> showLocationNotification(
    int id,
    String title,
    String body,
  ) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'reminder_location_channel_id',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          criticalAlert: true,
          displayOnForeground: true,
          displayOnBackground: true,
          backgroundColor: const Color(0xFF6C63FF),
        ),
      );
    } catch (e) {
      print('Error showing location notification: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;

  const MyApp({Key? key, required this.isFirstLaunch}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Is First Launch: $isFirstLaunch'); // Debug print
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8F9FF),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
        ),
      ),
      home:
          isFirstLaunch ? const IntroductionScreens() : const CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final List<Map<String, dynamic>> _reminders = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _isCalendarExpanded = false;
  final Map<String, int> _reminderIds = {};
  int _nextReminderId = 0;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    // Start location monitoring for geofences
    _locationService.startLocationMonitoring();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _locationService.stopLocationMonitoring();
    super.dispose();
  }

  void _addReminder(
    String title,
    String notes,
    DateTime deadline,
    String taskType, {
    bool isLocationBased = false,
    LatLng? locationLatLng,
    String? locationAddress,
  }) async {
    if (title.isNotEmpty) {
      final reminderId = _nextReminderId++;

      // Add geofence if it's a location-based reminder
      if (isLocationBased &&
          locationLatLng != null &&
          locationAddress != null) {
        final latLng = latlong2.LatLng(
          locationLatLng.latitude,
          locationLatLng.longitude,
        );
        _locationService.addGeofence(
          reminderId,
          title,
          latLng,
          locationAddress,
        );
      }

      setState(() {
        _reminders.add({
          'id': reminderId,
          'title': title,
          'notes': notes,
          'deadline': deadline,
          'taskType': taskType,
          'isLocationBased': isLocationBased,
          'locationLatLng': locationLatLng,
          'locationAddress': locationAddress,
        });
        _reminderIds[title + deadline.toString()] = reminderId;
      });

      try {
        final notificationService = NotificationService();
        final hasPermission = await Permission.notification.status;

        if (!hasPermission.isGranted) {
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Notification Permission Required'),
                    content: const Text(
                      'To receive reminders, please enable notifications for this app.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final granted =
                              await notificationService
                                  .requestNotificationPermissions();
                          if (granted && mounted) {
                            await notificationService.scheduleNotification(
                              title,
                              deadline,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Reminder set for ${DateFormat('MMM d, y • h:mm a').format(deadline)}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
            );
            return;
          }
        }

        await notificationService.scheduleNotification(title, deadline);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reminder set for ${DateFormat('MMM d, y • h:mm a').format(deadline)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error setting reminder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Failed to set reminder. Please check notification permissions.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () async {
                  await NotificationService().openNotificationSettings();
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _removeReminder(int id) {
    // Remove geofence if it exists
    _locationService.removeGeofence(id);

    setState(() {
      _reminders.removeWhere((reminder) => reminder['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final calendarHeight = screenHeight * 0.45;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FE),
      body: Stack(
        children: [
          // Background Design Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.2),
                    const Color(0xFF6C63FF).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.3,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4CAF50).withOpacity(0.15),
                    const Color(0xFF4CAF50).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // App Bar with Gradient
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.1),
                        const Color(0xFF4CAF50).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF6C63FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Checkpoint',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C63FF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none),
                              color: const Color(0xFF6C63FF),
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.person_outline),
                              color: const Color(0xFF6C63FF),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Calendar Section with Gradient Background
                Container(
                  height: calendarHeight,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, const Color(0xFFF5F6FF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Month Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_focusedDay),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 28),
                                color: const Color(0xFF6C63FF),
                                onPressed: () {
                                  setState(() {
                                    _focusedDay = DateTime(
                                      _focusedDay.year,
                                      _focusedDay.month - 1,
                                    );
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 28),
                                color: const Color(0xFF6C63FF),
                                onPressed: () {
                                  setState(() {
                                    _focusedDay = DateTime(
                                      _focusedDay.year,
                                      _focusedDay.month + 1,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Calendar
                      Expanded(
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate:
                              (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          headerVisible: false,
                          daysOfWeekHeight: 40,
                          rowHeight: 40,
                          calendarStyle: CalendarStyle(
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            weekendTextStyle: const TextStyle(
                              color: Color(0xFF6C63FF),
                            ),
                            defaultTextStyle: const TextStyle(
                              color: Colors.black87,
                            ),
                            outsideTextStyle: TextStyle(
                              color: Colors.grey[400],
                            ),
                            cellMargin: const EdgeInsets.all(4),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            weekendStyle: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tasks Section with Gradient Background
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, const Color(0xFFF5F6FF)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.task_alt,
                                      color: Color(0xFF6C63FF),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Upcoming Tasks',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6C63FF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.sort,
                                      color: Color(0xFF6C63FF),
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sort',
                                      style: TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: _buildRemindersList()),
                      ],
                    ),
                  ),
                ),
                // Add Button with Gradient
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      AddReminderScreen(onAdd: _addReminder),
                            ),
                          ).then((_) => setState(() {})),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Add Assignment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildRemindersList() {
    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return Dismissible(
          key: ValueKey(reminder['id']),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            _removeReminder(reminder['id']);
          },
          child: ReminderCard(
            key: ValueKey(reminder['id']),
            id: reminder['id'],
            title: reminder['title'],
            deadline: reminder['deadline'],
            onDelete: () => _removeReminder(reminder['id']),
            taskType: reminder['taskType'],
            isLocationBased: reminder['isLocationBased'] ?? false,
            locationLatLng: reminder['locationLatLng'],
            locationAddress: reminder['locationAddress'],
          ),
        );
      },
    );
  }
}

class ReminderCard extends StatefulWidget {
  final int id;
  final String title;
  final DateTime deadline;
  final VoidCallback onDelete;
  final bool isLocationBased;
  final String taskType;
  final LatLng? locationLatLng;
  final String? locationAddress;

  const ReminderCard({
    Key? key,
    required this.id,
    required this.title,
    required this.deadline,
    required this.onDelete,
    required this.taskType,
    this.isLocationBased = false,
    this.locationLatLng,
    this.locationAddress,
  }) : super(key: key);

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    widget.onDelete();
  }

  Future<void> _openGoogleMaps() async {
    if (widget.locationLatLng != null) {
      final lat = widget.locationLatLng!.latitude;
      final lng = widget.locationLatLng!.longitude;

      // Use the proper Android intent format for Google Maps
      final url = Uri.parse('google.navigation:q=$lat,$lng');

      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to web URL if Google Maps app is not installed
          final webUrl = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening Google Maps: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showLocationDetails() {
    if (widget.locationLatLng != null && widget.locationAddress != null) {
      showModalBottomSheet(
        context: context,
        builder:
            (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.locationAddress!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Lat: ${widget.locationLatLng!.latitude.toStringAsFixed(6)}\nLng: ${widget.locationLatLng!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openGoogleMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate with Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = TaskColors.getColorForCategory(widget.taskType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: categoryColor, width: 4)),
        ),
        child: InkWell(
          onTap: widget.isLocationBased ? _showLocationDetails : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Due: ${DateFormat('MMM d, y HH:mm').format(widget.deadline)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isLocationBased)
                      IconButton(
                        icon: const Icon(Icons.navigation),
                        onPressed: _openGoogleMaps,
                        color: Colors.green,
                        tooltip: 'Navigate to location',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _isDeleting ? null : _handleDelete,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.taskType,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.isLocationBased)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.locationAddress?.split(',')[0] ??
                                  'Location Alert',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddReminderScreen extends StatefulWidget {
  final Function(
    String title,
    String notes,
    DateTime deadline,
    String taskType, {
    bool isLocationBased,
    LatLng? locationLatLng,
    String? locationAddress,
  })
  onAdd;

  const AddReminderScreen({Key? key, required this.onAdd}) : super(key: key);

  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  DateTime? _selectedDateTime;
  String _taskType = "Unknown";
  bool _isLoading = false;
  bool _isLocationBased = false;
  LatLng? _selectedLocation;
  String? _locationAddress;
  final LocationService _locationService = LocationService();
  final PlaceRecommendationService _placeService = PlaceRecommendationService();
  Timer? _recommendationTimer;
  List<Map<String, dynamic>> _recommendedPlaces = [];

  @override
  void dispose() {
    _titleController.dispose();
    _recommendationTimer?.cancel();
    super.dispose();
  }

  void _startRecommendationTimer() {
    _recommendationTimer?.cancel();
    setState(() {
      _recommendedPlaces = []; // Clear previous recommendations
    });

    if (_taskType == "Unknown") return;

    _recommendationTimer = Timer(const Duration(seconds: 5), () async {
      try {
        final hasPermission = await _locationService.checkLocationPermission();
        if (!hasPermission) {
          final granted = await _locationService.requestLocationPermission();
          if (!granted) return;
        }

        final position = await _locationService.getCurrentLocation();
        final places = await _placeService.getNearbyPlaces(_taskType, position);

        if (mounted && places.isNotEmpty) {
          setState(() {
            _recommendedPlaces = places;
            if (places.isNotEmpty) {
              _isLocationBased = true;
              // Store the first place's coordinates by default
              _selectedLocation = LatLng(
                places.first['latitude'],
                places.first['longitude'],
              );
              _locationAddress = places.first['name'];
            }
          });
        }
      } catch (e) {
        print('Error getting recommendations: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error finding nearby places: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    try {
      final hasPermission = await _locationService.checkLocationPermission();

      if (!hasPermission) {
        if (mounted) {
          final result = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Location Permission Required'),
                  content: const Text(
                    'This app needs location permission to set location-based reminders. Would you like to enable it?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
          );

          if (result == true) {
            await _locationService.requestLocationPermission();
          }
        }
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LocationPicker()),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _selectedLocation = result['location'] as LatLng;
          _locationAddress = result['address'] as String;
        });
      }
    } catch (e) {
      print('Error picking location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _predictTaskType(String task) async {
    if (task.isEmpty) {
      setState(() {
        _taskType = "Unknown";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse("http://10.12.78.147:5000/predict"),
            headers: {"Content-Type": "application/json"},
            body: json.encode({"task": task}),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data["category"] != null) {
          setState(() {
            _taskType = data["category"];
          });
        } else {
          setState(() {
            _taskType = "Unknown";
          });
        }
      } else {
        setState(() {
          _taskType = "Unknown";
        });
      }
    } catch (e) {
      print('Error predicting task type: $e');
      setState(() {
        _taskType = "Unknown";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Assignment'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assignment Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Assignment Title',
                prefixIcon: Icon(Icons.title, color: Colors.indigo),
              ),
              onChanged: (value) {
                _predictTaskType(value);
                _startRecommendationTimer();
              },
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TaskColors.getColorForCategory(
                    _taskType,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: TaskColors.getColorForCategory(_taskType),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Category: $_taskType",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: TaskColors.getColorForCategory(_taskType),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Due Date & Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDateTime == null
                        ? 'Select Date & Time'
                        : DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(_selectedDateTime!),
                    style: TextStyle(
                      color:
                          _selectedDateTime == null
                              ? Colors.grey
                              : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Colors.indigo,
                    ),
                    onPressed: _pickDateTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text(
                'Location-based Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,
                ),
              ),
              subtitle: Text(
                _locationAddress ?? 'No location selected',
                style: TextStyle(color: Colors.grey),
              ),
              value: _isLocationBased,
              onChanged: (bool value) {
                setState(() {
                  _isLocationBased = value;
                  if (!value) {
                    _selectedLocation = null;
                    _locationAddress = null;
                  }
                });
              },
              activeColor: Colors.indigo,
            ),
            if (_isLocationBased) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.location_on),
                  label: Text(
                    _selectedLocation != null
                        ? 'Change Location'
                        : 'Select Location',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_recommendationTimer != null && _recommendedPlaces.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.indigo.withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Finding nearby places for ${_taskType.toLowerCase()}...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              if (_recommendedPlaces.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.recommend,
                                  color: Colors.indigo,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Recommended Places',
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_recommendedPlaces.length} places',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recommendedPlaces.length,
                          itemBuilder: (context, index) {
                            final place = _recommendedPlaces[index];
                            final isSelected =
                                _locationAddress == place['name'];
                            return Padding(
                              padding: EdgeInsets.only(
                                right:
                                    index == _recommendedPlaces.length - 1
                                        ? 0
                                        : 12,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 280,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      isSelected
                                          ? Colors.indigo.withOpacity(0.1)
                                          : Colors.white,
                                      isSelected
                                          ? Colors.indigo.withOpacity(0.05)
                                          : Colors.white,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Colors.indigo.withOpacity(0.5)
                                            : Colors.grey.withOpacity(0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedLocation = LatLng(
                                          place['latitude'],
                                          place['longitude'],
                                        );
                                        _locationAddress = place['name'];
                                        _isLocationBased = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.location_on,
                                                  color:
                                                      isSelected
                                                          ? Colors.indigo
                                                          : Colors.grey[600],
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  place['name'],
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                    color:
                                                        isSelected
                                                            ? Colors.indigo
                                                            : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.indigo
                                                        .withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.indigo,
                                                    size: 16,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.directions_car,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${((place['distance'] as double) / 1000).toStringAsFixed(1)}km away',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Tap to select',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.indigo
                                                    .withOpacity(0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedDateTime != null &&
                      (!_isLocationBased ||
                          (_isLocationBased && _selectedLocation != null))) {
                    widget.onAdd(
                      _titleController.text,
                      '', // Empty string for notes
                      _selectedDateTime!,
                      _taskType,
                      isLocationBased: _isLocationBased,
                      locationLatLng: _selectedLocation,
                      locationAddress: _locationAddress,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Add Assignment',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
