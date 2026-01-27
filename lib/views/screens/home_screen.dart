import 'package:flutter/material.dart';

enum PlanTier { starter, professional }

class HomeScreen extends StatelessWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;

  const HomeScreen({
    super.key,
    this.planTier = PlanTier.starter,
    this.unlockedCourseIds = const {'api510'},
  });

  @override
  Widget build(BuildContext context) {
    return HomeDashboard(
      planTier: planTier,
      unlockedCourseIds: unlockedCourseIds,
    );
  }
}

class HomeDashboard extends StatelessWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;

  const HomeDashboard({
    super.key,
    required this.planTier,
    required this.unlockedCourseIds,
  });

  bool _isUnlocked(Course course) => unlockedCourseIds.contains(course.id);

  @override
  Widget build(BuildContext context) {
    final String planLabel =
        planTier == PlanTier.professional ? 'Professional User' : 'Starter User';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _HeaderSection(planTier: planTier),
          const SizedBox(height: 16),
          _AnnouncementBanner(
            text:
                'Welcome to the new "Inspector\'s Path"\nNew content for API 570 has been added.',
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome back, $planLabel!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a Certification to start practicing',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 16),
          ..._courses.map((course) {
            final isUnlocked = _isUnlocked(course);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CourseCard(
                course: course,
                isUnlocked: isUnlocked,
                showPriceUnlock: planTier == PlanTier.professional,
                onTap: () {},
              ),
            );
          }),
          const SizedBox(height: 12),
          const _DisclaimerSection(),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final PlanTier planTier;

  const _HeaderSection({required this.planTier});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundImage: AssetImage('assets/images/onboarding1.png'),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Madiha Lata',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Hi, Good Morning',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        _PlanChip(planTier: planTier),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  final PlanTier planTier;

  const _PlanChip({required this.planTier});

  @override
  Widget build(BuildContext context) {
    final bool isPro = planTier == PlanTier.professional;
    final Color bgColor = isPro ? const Color(0xFFE8F7EC) : const Color(0xFF2D4F88);
    final Color borderColor =
        isPro ? const Color(0xFF2DBD67) : const Color(0xFF2D4F88);
    final Color textColor = isPro ? const Color(0xFF1D7A44) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            isPro ? 'Professional' : 'Starter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementBanner extends StatelessWidget {
  final String text;

  const _AnnouncementBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4B6AAE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3E5A97), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final Course course;
  final bool isUnlocked;
  final bool showPriceUnlock;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.isUnlocked,
    required this.showPriceUnlock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9D9E3), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                course.imageAsset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CourseStatus(
              isUnlocked: isUnlocked,
              showPriceUnlock: showPriceUnlock,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseStatus extends StatelessWidget {
  final bool isUnlocked;
  final bool showPriceUnlock;

  const _CourseStatus({
    required this.isUnlocked,
    required this.showPriceUnlock,
  });

  @override
  Widget build(BuildContext context) {
    if (isUnlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _StatusDot(
            color: Color(0xFF2DBD67),
            icon: Icons.check,
          ),
          SizedBox(width: 6),
          Text(
            'Unlocked',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2DBD67),
            ),
          ),
        ],
      );
    }

    if (showPriceUnlock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2DBD67),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Unlock for \$150',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _StatusDot(
          color: Color(0xFFE24B4B),
          icon: Icons.lock,
        ),
        SizedBox(width: 6),
        Text(
          'Locked',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE24B4B),
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _StatusDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 14,
      ),
    );
  }
}

class _DisclaimerSection extends StatelessWidget {
  const _DisclaimerSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: 'Not affiliated with or endorsed by API. ',
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          children: const [
            TextSpan(
              text: 'See full disclaimer.',
              style: TextStyle(
                color: Color(0xFF2F6DE0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class Course {
  final String id;
  final String title;
  final String subtitle;
  final String imageAsset;

  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
  });
}

const List<Course> _courses = [
  Course(
    id: 'api510',
    title: 'API 510 - Pressure vessel Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding1.png',
  ),
  Course(
    id: 'api570',
    title: 'API 570 - Piping Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding2.png',
  ),
  Course(
    id: 'api653',
    title: 'API 653 - Aboveground Storage Tanks Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding3.png',
  ),
  Course(
    id: 'api1169',
    title: 'API 1169 - Pipeline Construction Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding4.png',
  ),
  Course(
    id: 'api936',
    title: 'API 936 - Refractory Personnel',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding1.png',
  ),
  Course(
    id: 'sife',
    title: 'SIFE - Source Inspector Fixed Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding2.png',
  ),
  Course(
    id: 'sire',
    title: 'SIRE - Source Inspector Rotating Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding3.png',
  ),
  Course(
    id: 'siee',
    title: 'SIEE - Source Inspector Electrical Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding4.png',
  ),
];
