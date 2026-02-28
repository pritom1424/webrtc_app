import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/constants/app_colors.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/profile/provider/profile_notifier.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final user = profileState.user;
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryBlue,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Guest User',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "@${user?.loginId ?? "guest"}",
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.help_outline_rounded,
                  title: 'FAQ',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqPage()),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Helpdesk',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpDeskPage()),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.mail_outline_rounded,
                  title: 'Contact Us',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactPage()),
                    );
                  },
                ),
                const Divider(height: 24, indent: 16, endIndent: 16),
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textDark;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? AppColors.primaryBlue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: itemColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'About',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset("assets/images/company-page-banner.png"),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'BDCOM',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          const Center(
            child: Text(
              'Connecting Progress',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          _InfoCard(
            title: 'We Are BDCOM',
            body:
                '''BDCOM Online Ltd. is a publicly traded company listed on the Dhaka Stock Exchange (DSE) and Chittagong Stock Exchange (CSE), having its successful journey of over two decades as an Internet Service Provider (ISP) and ICT Service & Solution Provider. BDCOM was initially incorporated as a private limited company under the Companies Act of 1994 on 12th February 1997. Subsequently, on 12th December 2001, BDCOM was converted into a Public Limited Company. On 10th February 2002, the company transitioned into a listed company through an Initial Public Offering (IPO).

Since its incorporation back in 1997, BDCOM has consistently been a trusted and forward-looking ICT service and solution provider, committed to building nationwide ICT services and solutions compatible with the demands of the 21st century. BDCOM operates under the licensing authority of the Bangladesh Telecommunication Regulatory Commission (BTRC).

With its diversified business policies and experienced, strong management capacity, BDCOM has consistently held significant market leadership in various sectors including ISP, IP Telephony, Telematics (VTS), and the Software industry. BDCOM has established a robust countrywide MPLS network covering 495 Upazilas out of 495 in the country.''',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Values',
            body:
                '''BDCOM Online Ltd., a business house with a framework of ethics, focus on customer insights and priorities, compliant with rules, transparent on policies, and with a target on achieving the highest standard and quality of services that we provide with the underpinning values.''',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Nature of Business',
            body:
                '''BDCOM is a trusted name for Nationwide Internet Service, Secured Data Connectivity, IP Telephony Service, System Integration & Managed Service. Along with these services Software Development, Vehicle Tracking and Fleet Management Solution, IT Infrastructure Development, BPO and many more are served from the house of BDCOM. From the beginning BDCOM envisaged "Total Excellence” as its principle for guiding light, around which revolves its entire spectrum of activities. With the unique vision, BDCOM is the forerunner in the value centric service marketplace and an architect of high value end-to-end ICT solutions for both National and International market.

BDCOM has more implementations, dedicated engineers and technological expertise than any other Data Communication player in the market. BDCOM's financial strength, experienced management team, strong solution portfolio, and diversified sales base will ensure that it strengthens its already formidable position as the leading Data Communication Solutions Provider in the Wireless Communication market.''',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Executive Summary',
            body:
                '''BDCOM Online Ltd. was incorporated under the Companies Act. 1994 on 12th February, 1997 as a Private Limited Company with an authorized capital of Tk. 10,000,000.00 consisting of 100,000 ordinary shares of Tk. 100.00 each. On 12 December 2001, BDCOM was converted into a Public Limited Company with an authorized capital of Tk. 250,000,000.00 consisting of 25,000,000 ordinary shares of Tk. 10.00 each. At present authorized capital of Tk. 1,000,000,000.00 consisting of 100,000,000 ordinary shares of Tk.10.00 each increased as on 29 June 2010. At present paid up capital of the Company is Tk. 599,408,240.00 consisting of 59,940,824 ordinary shares of Tk. 10 each.

Name and Address
Name of the Company: BDCOM ONLINE LTD.
Registered Office:	Rangs Nilu Square, Level-5
House: 75, Road: 5/A, Satmosjid Road
Dhanmondi, Dhaka-1209, Bangladesh
Corporate Head Office:	JL Bhaban (5th floor)
House # 1, Road # 1, Gulshan-1
Gulshan Avenue, Dhaka-1212, Bangladesh
Phone:	+8809666 333 666
Email:	office@bdcom.com
Web Site:	www.bdcom.com
www.bdcom.net
Certificate of Incorporation	
Number:	C-32328(1449)/97
Date:	12th February, 1997
Registered To:	Registrar of Joint Stock Companies and Firms of Bangladesh, Dhaka, Bangladesh
Listed in Stock Exchange (s):	Dhaka Stock Exchange PLC.
Chittagong Stock Exchange PLC.
“A” Category
Credit Rating:	by EMERGING Credit Rating Ltd, Bangladesh on December 30, 2024 up to December 29, 2025
Rating Action:	Surveillance-2
Long Term rating:	AA
Short Term Rating:	ST-2
Outlook:	Stable
Number of years in operation:	28 years (+)
ISO Certification	
Name:	ISO 9001:2015
Certificate No.:	BQSR25338
Registration Date:	01/06/2024
Issue Date:	01/06/2024
Expiry Date:	31/05/2027
Issued By:	BQSR Systems Registech Private Limited, USA''',
          ),
        ],
      ),
    );
  }
}

// FAQ Page

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const _categories = [
    'BDCOM Online Ltd.',
    'Smile Broadband',
    'Broadband360',
    'Kotha IP Telephony',
    'Smarttracker',
    'Environment Monitoring System',
    'Support & Contact',
  ];

  static const _faqsByCategory = [
    // 0 — BDCOM Online Ltd.
    [
      (
        q: 'What is BDCOM Online Ltd.?',
        a: 'BDCOM Online Ltd. is one of the leading internet and technology service providers in Bangladesh, established in 1997. We provide internet, data connectivity, cloud, communication, and tracking solutions for individuals, businesses, and enterprises.',
      ),
      (
        q: 'What services does BDCOM Online Ltd. offer?',
        a: 'High-speed internet (Smile Broadband, Broadband360 & Corporate Dedicated Internet), IP Telephony (Kotha.com.bd), GPS tracking & fleet management (Smarttracker.com.bd), data center and enterprise hosting solutions, and Environment Monitoring System (EMS).',
      ),
    ],
    // 1 — Smile Broadband
    [
      (
        q: 'What is Smile Broadband?',
        a: 'Smile Broadband is BDCOM\'s reliable internet service designed for homes and offices, providing secure, stable, and affordable connectivity.',
      ),
      (
        q: 'How can I subscribe to Smile Broadband?',
        a: 'You can visit www.smile.com.bd or call our hotline 09666 666 666 to check packages and request a new connection.',
      ),
      (
        q: 'Where is Smile Broadband available?',
        a: 'Smile Broadband covers major areas in Dhaka, Chattogram, and other key cities of Bangladesh.',
      ),
    ],
    // 2 — Broadband360
    [
      (
        q: 'What is Broadband360?',
        a: 'Broadband360 is a premium internet service by BDCOM that ensures ultra-fast, seamless, and secure connectivity for advanced users and businesses.',
      ),
      (
        q: 'Who should choose Broadband360?',
        a: 'It is ideal for professionals, gamers, streamers, and businesses requiring higher bandwidth and reliable performance.',
      ),
      (
        q: 'How do I learn more about Broadband360 packages?',
        a: 'Visit www.broadband360.com.bd to explore packages and apply online.',
      ),
    ],
    // 3 — Kotha IP Telephony
    [
      (
        q: 'What is Kotha?',
        a: 'Kotha is a communication platform developed by BDCOM that provides IP telephony and value-added voice services for individuals and businesses.',
      ),
      (
        q: 'How can I start using Kotha?',
        a: 'Simply register at www.kotha.com.bd and follow the setup guide to activate your communication services.',
      ),
    ],
    // 4 — Smarttracker
    [
      (
        q: 'What is Smarttracker?',
        a: 'Smarttracker is BDCOM\'s GPS-based vehicle tracking and fleet management solution. It helps individuals and businesses monitor vehicles in real-time, ensuring safety and efficiency.',
      ),
      (
        q: 'What features does Smarttracker provide?',
        a: 'Real-time GPS tracking, trip history and reports, fuel monitoring, geo-fencing alerts, and a fleet management dashboard.',
      ),
      (
        q: 'How can I subscribe to Smarttracker?',
        a: 'Visit www.smarttracker.com.bd or contact our support team to learn more about packages and device installation.',
      ),
    ],
    // 5 — EMS
    [
      (
        q: 'What is BDCOM EMS?',
        a: 'BDCOM EMS is an advanced Environment Monitoring System designed to monitor critical environmental parameters such as temperature, humidity, smoke, liquid leakage, voltage, current, energy, and frequency. It offers real-time monitoring, alerts, historical data access, and smart automation features.',
      ),
      (
        q: 'What kind of sensors does BDCOM EMS support?',
        a: 'Temperature & Humidity Sensors, Smoke and Heat Detectors, Liquid Leakage Sensors, Voltage/Current/Frequency/Energy Meters, and Motion Sensors (optional).',
      ),
      (
        q: 'Why do I need an EMS for my organization?',
        a: 'EMS helps protect your sensitive equipment (servers, networking devices, data centers, ATMs, BTS sites, warehouses) from environmental risks. Early alerts can prevent downtime, equipment failure, and financial loss.',
      ),
      (
        q: 'How does BDCOM EMS notify users about issues?',
        a: 'Physical Alerts: On-site buzzer activates when thresholds are crossed. Digital Alerts: Sends SMS, email, or app notifications.',
      ),
      (
        q: 'Is EMS cloud-based or on-premises?',
        a: 'Both options are available — cloud-based dashboard for remote access, or on-premises setup for sensitive organizations requiring local monitoring.',
      ),
      (
        q: 'Can I view historical or archived data?',
        a: 'Yes. BDCOM EMS stores historical data with timestamps. Users can view, filter, and export this data from the web panel or mobile app for reporting, analysis, or compliance needs.',
      ),
      (
        q: 'Is internet connection mandatory?',
        a: 'Internet is required for remote access and digital alerts. However, core monitoring and local alerts (like buzzer or display) can function without the internet, ensuring basic operations continue during network outages.',
      ),
      (
        q: 'Is the system customizable for large facilities?',
        a: 'Yes. BDCOM EMS is modular and scalable. It can monitor hundreds of sensors across multiple zones and be tailored to meet the needs of large industrial, commercial, or institutional facilities.',
      ),
    ],
    // 6 — Support & Contact
    [
      (
        q: 'How can I contact BDCOM for support?',
        a: 'Hotline: 09666 666 666\nWebsite: www.bdcom.com\nEmail: helpdesk@bdcom.com',
      ),
      (
        q: 'What are the support hours?',
        a: 'Our helpdesk is available 24/7. You can reach us at 09666 666 666 or email helpdesk@bdcom.com at any time.',
      ),
      (
        q: 'Where is BDCOM\'s corporate office?',
        a: 'JL Bhaban (5th floor), House # 1, Road # 1, Gulshan Avenue, Gulshan-1, Dhaka-1212, Bangladesh. Phone: +88 09666 333 666',
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return const _FaqScaffold();
  }
}

class _FaqScaffold extends StatefulWidget {
  const _FaqScaffold();

  @override
  State<_FaqScaffold> createState() => _FaqScaffoldState();
}

class _FaqScaffoldState extends State<_FaqScaffold> {
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    final faqs = FaqPage._faqsByCategory[_selectedCategory];

    return _InfoScaffold(
      title: 'FAQ',
      icon: Icons.help_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBlue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCategory,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryBlue,
                ),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: List.generate(
                  FaqPage._categories.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(FaqPage._categories[i]),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          //FAQ Items
          ...faqs.map((faq) => _FaqItem(question: faq.q, answer: faq.a)),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  widget.answer,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Helpdesk Page

class HelpDeskPage extends StatelessWidget {
  const HelpDeskPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Helpdesk',
      icon: Icons.privacy_tip_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(
            title: 'Helpdesk',
            body:
                'With a team of experienced engineers, BDCOM are committed to provide comprehensive support and Helpdesk services to its clients for any problem related to the service. BDCOM has a very large support team to ensure the support center is available 24/7, 365 days a year. BDCOM always ensures that clients get a timely response to any issues and frequent updates on the progress in dealing with the issue.\n\n24/7 Helpdesk: +8809666 666 666 or helpdesk@bdcom.com',
          ),
        ],
      ),
    );
  }
}

// ── Contact Page ───────────────────────────────────────────────────────────

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Contact Us',
      icon: Icons.mail_outline_rounded,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF08083A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  "Contact",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Let's make your business communication more convenient with BDCOM Online Ltd.",
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 10),
                Chip(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  label: Text("09666 666 666"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Get Free Support",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "Leave your name, phone number, and purpose below, our team will contact you immediately.",
                ),

                SizedBox(height: 25),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Login ID field
                    TextField(
                      // controller: _loginIdController,
                      style: const TextStyle(color: AppColors.textDark),
                      decoration: const InputDecoration(hintText: 'Full Name'),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      // controller: _loginIdController,
                      style: const TextStyle(color: AppColors.textDark),
                      decoration: const InputDecoration(hintText: 'Contact'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      // controller: _loginIdController,
                      style: const TextStyle(color: AppColors.textDark),
                      decoration: const InputDecoration(hintText: 'Email'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      maxLines: 5,
                      // controller: _loginIdController,
                      style: const TextStyle(color: AppColors.textDark),
                      decoration: const InputDecoration(hintText: 'Purpose'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () {}, child: Text("Submit")),
                    // Password field
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shared Scaffold

class _InfoScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoScaffold({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Shared Info Card

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
