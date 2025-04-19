# Checkpoint Location Based Task Reminder

# Developed By:
1. Shobhit Choudhury
2. Abhyuday Tripathi
3. Yash Singhal

   
# About The App
Checkpoint is a smart task and location-based reminder application designed to help users manage their tasks and appointments efficiently. Here are its key features:

#Task Management:
Users can create and organize tasks with titles, due dates, and categories.
The app automatically categorizes tasks (e.g., Personal, Home Maintenance, Fitness/Health, etc.) based on the task title, likely using a backend API for prediction.
Tasks are displayed in a clean, card-based interface with color-coded categories for easy identification.

# Location-Based Reminders:
Users can set location-based reminders, meaning they will receive notifications when they are near a specific location relevant to their task.
The app uses the device's GPS (via the geolocator package) to monitor the user's location and trigger reminders accordingly.
Geofencing technology is employed to create virtual boundaries around specified locations.

# Smart Place Recommendations:
The app suggests nearby places relevant to the task category. For example, if a task is categorized as "Shopping," the app will recommend nearby shopping locations.
This feature likely uses an external API (like Google Places) to fetch place data based on the user's current location and task type.

# Calendar Integration:
Tasks and reminders are integrated into a calendar view, allowing users to see their schedule at a glance.
The calendar is interactive, enabling users to select dates and view tasks scheduled for specific days.

# Navigation Assistance:
For location-based tasks, the app provides a button to open Google Maps directly, offering directions to the task location.
This feature uses the url_launcher package to open the Google Maps app or web version, enhancing the user's ability to reach their destination.

# Notifications:
The app sends notifications to remind users of upcoming tasks and when they are near a location relevant to their task.
Notifications are managed using the awesome_notifications package, ensuring timely alerts.

# User-Friendly Interface:
The app features a modern, visually appealing UI with gradients, animations, and intuitive navigation.
It includes an introduction screen for first-time users, explaining the app's features and functionality.
In summary, Checkpoint is a comprehensive task management tool that combines traditional to-do list features with smart location-based reminders and place recommendations, all wrapped in a user-friendly interface. It aims to help users stay organized and never miss an important task or appointment, whether they are at home or on the go.
