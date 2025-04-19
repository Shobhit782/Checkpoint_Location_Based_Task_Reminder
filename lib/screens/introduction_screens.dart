import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class IntroductionScreens extends StatefulWidget {
  const IntroductionScreens({Key? key}) : super(key: key);

  @override
  _IntroductionScreensState createState() => _IntroductionScreensState();
}

class _IntroductionScreensState extends State<IntroductionScreens> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to Checkpoint',
      'description':
          'Your personal task and location-based reminder assistant. Never miss an important task or appointment again!',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF6C63FF),
    },
    {
      'title': 'Smart Task Management',
      'description':
          'Automatically categorize your tasks and get intelligent recommendations for the best places to complete them.',
      'icon': Icons.auto_awesome,
      'color': Color(0xFF4CAF50),
    },
    {
      'title': 'Location-Based Reminders',
      'description':
          'Get notified when you\'re near relevant locations. Perfect for errands, shopping, and appointments.',
      'icon': Icons.location_on,
      'color': Color(0xFFE91E63),
    },
    {
      'title': 'Get Started',
      'description':
          'Ready to take control of your tasks? Let\'s begin organizing your life with Checkpoint!',
      'icon': Icons.rocket_launch,
      'color': Color(0xFFFF9800),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntroduction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage]['color'].withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
          ),
          // Page content
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _pages[index]['color'].withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _pages[index]['icon'],
                        size: 60,
                        color: _pages[index]['color'],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Title
                    Text(
                      _pages[index]['title'],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _pages[index]['color'],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Description
                    Text(
                      _pages[index]['description'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          // Bottom navigation
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Page indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            _currentPage == index
                                ? _pages[index]['color']
                                : _pages[index]['color'].withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Next/Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeIntroduction();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage]['color'],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
}
