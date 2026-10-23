# ClearPass — Adelaide Tambo Library Digital Visitor Register

ClearPass is a Flutter-based digital visitor registration application developed for Adelaide Tambo Library. It is designed to replace the traditional paper-based visitor register with a modern, user-friendly digital experience.

The application allows visitors to sign in by providing their details and selecting a reason for their visit. It also includes an administrative dashboard for reviewing visitor activity and monitoring registration statistics.

## Project Overview

**Project Name:** ClearPass  
**Organisation:** Adelaide Tambo Library  
**Application Type:** Digital Visitor Register  
**Platform:** Flutter Web  
**Primary Purpose:** Digital visitor sign-in, sign-out, and visit activity monitoring.

## Features

### Visitor Registration

- Register visitors digitally instead of using a paper register.
- Capture visitor names and contact numbers.
- Select a reason for visiting from a predefined dropdown list.
- Display the current date and local time.
- Recognise returning visitors by normalised name and update their visit information.
- Record individual visit events, including sign-in and sign-out times.
- Display confirmation messages when visitors sign in or out.

### Administrative Dashboard

- Provide a separate administrative view.
- Display visitor and visit statistics.
- Show the number of unique visitors.
- Track visitors currently inside the library.
- Display total recorded visits.
- Filter statistics by today, the last seven days, or the last thirty days.
- Review visit activity and statistics by reason for visiting.

### User Interface and Design

- Modern interface inspired by liquid-glass design.
- Responsive layouts for different screen sizes.
- Consistent colours, typography, and visual styling.
- Subtle animations and interactive components.
- Clear navigation between the visitor register and administrative dashboard.

## Reasons for Visiting

The registration form supports the following visit categories:

- Public Facilities — Study
- Public Facilities — Research
- Public Facilities — Reading
- IT Facilities — Internet
- IT Facilities — Computing
- IT Facilities — Typing
- Library Facilities

These categories can be used to understand how visitors make use of the library's facilities.

## Technology Stack

- **Flutter:** Application framework.
- **Dart:** Programming language.
- **Material Design:** User interface components.
- **Git:** Version control.
- **GitHub:** Remote source-code repository.
- **Chrome:** Browser for local web development and testing.

## Project Structure

```text
adelaide_register/
├── android/                  # Android platform configuration
├── frontend/                 # Additional frontend source copy
│   └── lib/
├── ios/                      # iOS platform configuration
├── lib/                      # Main Flutter application source
│   ├── main.dart             # Application entry point
│   ├── models/
│   │   ├── visitor.dart      # Visitor data model
│   │   └── visit_event.dart  # Visit event data model
│   ├── screens/
│   │   └── register_screen.dart
│   └── utils/
│       └── app_constants.dart
├── linux/                    # Linux platform configuration
├── macos/                    # macOS platform configuration
├── test/                     # Flutter tests
├── web/                      # Web application configuration
├── windows/                  # Windows platform configuration
├── pubspec.yaml              # Dependencies and project configuration
├── pubspec.lock              # Resolved package versions
├── analysis_options.yaml      # Dart analysis rules
└── README.md                 # Project documentation
```

The root `lib/` directory is the primary source directory for the Flutter application. The additional `frontend/lib/` directory is retained in the repository while the project structure is being consolidated.

## Getting Started

### Prerequisites

Install the following tools on your development computer:

1. Flutter SDK.
2. Git.
3. Visual Studio Code or another compatible code editor.
4. Google Chrome for running the web application.

Verify the Flutter installation:

```bash
flutter doctor
```

### Clone the Repository

Clone the project from GitHub:

```bash
git clone https://github.com/AvelaSelomane/adelaide-register.git
```

Move into the project directory:

```bash
cd adelaide-register
```

### Install Dependencies

Download the required Flutter packages:

```bash
flutter pub get
```

### Run the Application

Launch ClearPass in Google Chrome:

```bash
flutter run -d chrome
```

If Chrome is not detected, check the Flutter web setup and available devices with:

```bash
flutter devices
```

### Analyse the Source Code

Run the Dart and Flutter static analyser:

```bash
flutter analyze
```

### Run Tests

Execute the project's Flutter tests:

```bash
flutter test
```

Review any failing tests before considering a build ready for release.

## Version Control and GitHub

The project is maintained using Git and hosted in a private GitHub repository.

Repository: https://github.com/AvelaSelomane/adelaide-register

To save future changes:

```bash
git add .
git commit -m "Describe your changes"
git push
```

To retrieve changes on another computer, open the cloned repository and run:

```bash
git pull
flutter pub get
```

## Data Storage

The current application maintains visitor and visit-event information in application memory. Unless persistent storage is added, this information is not guaranteed to survive an application restart and is not automatically shared between computers.

A future production version should use an appropriate persistent database and, where multiple devices need access, a shared backend with suitable access controls.

## Security and Privacy

ClearPass is intended to handle visitor information, including names and contact numbers. Any real deployment should:

- Protect visitor information from unauthorised access.
- Use secure authentication and authorisation for administrative functions.
- Avoid storing passwords or private credentials in source code.
- Keep secrets out of Git and GitHub.
- Restrict access to visitor records to authorised personnel.
- Define suitable data retention and deletion procedures.
- Follow applicable privacy and data-protection requirements.

The current administrative login implementation should be reviewed and strengthened before the application is used in a real library environment. A private GitHub repository does not replace application security.

## Future Improvements

Potential future enhancements include:

- Persistent database storage.
- Secure administrator authentication.
- Shared access to visitor records across devices.
- Visitor activity reports and downloadable PDF reports.
- Improved analytics and visual charts.
- Automated backups and data retention controls.
- Deployment as a hosted web application.

## Project Status

**Development status:** In development.

ClearPass is being developed to modernise visitor registration at Adelaide Tambo Library. Features and implementation details may change as development continues.

## Author and Project Purpose

ClearPass is a software development project focused on improving the visitor registration process, reducing reliance on paper records, and providing clearer insights into library facility usage.

---

*ClearPass — Adelaide Tambo Library Digital Visitor Register.*