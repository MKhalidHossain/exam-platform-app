import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/plan_tier.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../models/exam_model.dart';
import '../widgets/unlock_exam_dialog.dart';
import '../../services/exam_service.dart';

class HomeScreen extends StatelessWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;

  const HomeScreen({
    super.key,
    this.planTier = PlanTier.starter,
    this.unlockedCourseIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());

    return Obx(() {
      final user = userController.user.value;
      final effectivePlan =
          user == null ? planTier : userController.planTier.value;
      final effectiveUnlocked = user == null &&
              userController.unlockedExamIds.value.isEmpty
          ? unlockedCourseIds
          : userController.unlockedExamIds.value;

      return HomeDashboard(
        planTier: effectivePlan,
        unlockedCourseIds: effectiveUnlocked,
        user: user,
      );
    });
  }
}

class HomeDashboard extends StatelessWidget {
  final PlanTier planTier;
  final Set<String> unlockedCourseIds;
  final UserModel? user;

  const HomeDashboard({
    super.key,
    required this.planTier,
    required this.unlockedCourseIds,
    this.user,
  });

  bool _isUnlocked(CourseItem course) {
    if (course.isUnlocked == true) return true;
    if (course.isUnlocked == false) return false;
    final String rawId = (course.examId ?? course.id).trim();
    if (rawId.isEmpty) return false;
    if (unlockedCourseIds.contains(rawId)) return true;
    final String normalized = rawId.toLowerCase();
    return unlockedCourseIds.any(
      (id) => id.trim().toLowerCase() == normalized,
    );
  }

  void _showLoading(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoading(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _unlockExam(
    BuildContext context,
    ExamModel exam,
  ) async {
    final examId = exam.id.trim();
    if (examId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam ID missing. Please try again.')),
      );
      return;
    }

    final ApiService apiService = ApiService();
    final UserController userController = Get.isRegistered<UserController>()
        ? Get.find<UserController>()
        : Get.put(UserController());
    bool loadingShown = false;

    void showLoading(String message) {
      if (loadingShown) return;
      _showLoading(context, message);
      loadingShown = true;
    }

    void hideLoading() {
      if (!loadingShown) return;
      _hideLoading(context);
      loadingShown = false;
    }

    try {
      showLoading('Preparing secure checkout...');
      final createRes = await apiService.createExamStripePaymentIntent(examId);
      if (!context.mounted) return;
      hideLoading();

      if (!createRes.success || createRes.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(createRes.message ?? 'Failed to create payment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bool alreadyUnlocked =
          createRes.data?['unlocked'] == true ||
          createRes.data?['alreadyUnlocked'] == true;
      if (alreadyUnlocked) {
        await userController.addUnlockedExamId(examId);
        await userController.refreshProfile();
        if (!context.mounted) return;
        context.push(
          '/quiz-settings',
          extra: {
            'courseTitle': exam.name,
            'examId': examId,
            'questionCount': exam.questionCount,
            'effectivitySheetContent': exam.effectivitySheetContent,
            'bodyOfKnowledgeContent': exam.bodyOfKnowledgeContent,
          },
        );
        return;
      }

      final clientSecret = createRes.data!['clientSecret'] as String?;
      final paymentIntentId = createRes.data!['paymentIntentId'] as String?;
      if (clientSecret == null || clientSecret.isEmpty || paymentIntentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid payment response'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'EJ Exam Access',
          returnURL: 'flutterstripe://redirect',
        ),
      );
      if (!context.mounted) return;

      await Stripe.instance.presentPaymentSheet();
      if (!context.mounted) return;

      showLoading('Confirming payment...');
      final confirmRes =
          await apiService.confirmExamStripePayment(examId, paymentIntentId);
      if (!context.mounted) return;
      hideLoading();

      if (confirmRes.success) {
        await userController.applyProfessionalUpgrade(examId: examId);
        await userController.refreshProfile();
        if (!context.mounted) return;
        context.push(
          '/exam-unlock-success',
          extra: {
            'courseTitle': exam.name,
            'examId': examId,
            'questionCount': exam.questionCount,
            'effectivitySheetContent': exam.effectivitySheetContent,
            'bodyOfKnowledgeContent': exam.bodyOfKnowledgeContent,
            'amountPaid': 150,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirmRes.message ?? 'Failed to confirm payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on StripeException catch (e) {
      if (!context.mounted) return;
      hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.message ?? 'Stripe error'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      hideLoading();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    final String planLabel = planTier.userLabel;
    final String primaryName = (user?.name ?? '').trim();
    final String fallbackName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    final String displayName = primaryName.isNotEmpty
        ? primaryName
        : (fallbackName.isNotEmpty ? fallbackName : planLabel);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _HeaderSection(planTier: planTier, user: user),
          const SizedBox(height: 16),
          _AnnouncementBanner(
            text:
                'Welcome to the new "Inspector\'s Path"\nNew content for API 570 has been added.',
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome back, $displayName!',
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
          Obx(() {
            final bool isLoading = controller.isLoading.value;
            final List<CourseItem> items = controller.exams.isNotEmpty
                ? controller.exams
                    .map(
                      (exam) => CourseItem(
                        id: exam.id ?? exam.name ?? '',
                        title: exam.name ?? 'Certification Exam',
                        subtitle: 'Master your certification exam',
                        imageUrl: exam.image?.url,
                        imageAsset: 'assets/images/onboarding1.png',
                        examId: exam.id,
                        questionCount: exam.questionCount,
                        effectivitySheetContent: exam.effectivitySheetContent,
                        bodyOfKnowledgeContent: exam.bodyOfKnowledgeContent,
                        isUnlocked: exam.unlocked,
                        unlockPrice: exam.unlockPrice,
                        currency: exam.currency,
                      ),
                    )
                    .toList()
                : _courses;
            final unlockedItems = <CourseItem>[];
            final lockedItems = <CourseItem>[];
            for (final course in items) {
              if (_isUnlocked(course)) {
                unlockedItems.add(course);
              } else {
                lockedItems.add(course);
              }
            }
            final orderedItems = [...unlockedItems, ...lockedItems];

            if (isLoading && controller.exams.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return Column(
              children: orderedItems.map((course) {
                final isUnlocked = _isUnlocked(course);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CourseCard(
                    course: course,
                    isUnlocked: isUnlocked,
                    showPriceUnlock: planTier == PlanTier.professional,
                    onTap: () {
                      if (isUnlocked || planTier == PlanTier.starter) {
                        context.push(
                          '/quiz-settings',
                          extra: {
                            'courseTitle': course.title,
                            'examId': course.examId ?? course.id,
                            'questionCount': course.questionCount,
                            'effectivitySheetContent':
                                course.effectivitySheetContent,
                            'bodyOfKnowledgeContent':
                                course.bodyOfKnowledgeContent,
                          },
                        );
                        return;
                      }

                      showDialog<UnlockExamDialogResult>(
                        context: context,
                        barrierDismissible: false,
                        builder: (dialogContext) => UnlockExamDialog(
                          examService: ExamService(),
                          maxSelect: 1,
                          initialSelectedId: course.examId ?? course.id,
                          unlockedIds: unlockedCourseIds,
                        ),
                      ).then((result) {
                        if (result == null) return;
                        if (result.alreadyUnlocked) {
                          context.push(
                            '/quiz-settings',
                            extra: {
                              'courseTitle': result.exam.name,
                              'examId': result.exam.id,
                              'questionCount': result.exam.questionCount,
                              'effectivitySheetContent':
                                  result.exam.effectivitySheetContent,
                              'bodyOfKnowledgeContent':
                                  result.exam.bodyOfKnowledgeContent,
                            },
                          );
                          return;
                        }
                        _unlockExam(context, result.exam);
                      });
                    },
                  ),
                );
              }).toList(),
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
  final UserModel? user;

  const _HeaderSection({required this.planTier, this.user});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatar;
    final primaryName = (user?.name ?? '').trim();
    final fallbackName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    final userName = primaryName.isNotEmpty
        ? primaryName
        : (fallbackName.isNotEmpty ? fallbackName : 'User');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : const AssetImage('assets/images/onboarding1.png')
                  as ImageProvider,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hi, Good Morning',
                style: const TextStyle(
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
  final CourseItem course;
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
              child: course.imageUrl != null && course.imageUrl!.isNotEmpty
                  ? Image.network(
                      course.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          course.imageAsset,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
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
              unlockPrice: course.unlockPrice,
              currency: course.currency,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatUnlockLabel(double? price, String? currency) {
  if (price == null) return 'Unlock for \$150';
  final trimmedCurrency = currency?.trim().toUpperCase();
  final formatted =
      price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  if (trimmedCurrency == null || trimmedCurrency.isEmpty || trimmedCurrency == 'USD') {
    return 'Unlock for \$$formatted';
  }
  return 'Unlock for $trimmedCurrency $formatted';
}

class _CourseStatus extends StatelessWidget {
  final bool isUnlocked;
  final bool showPriceUnlock;
  final double? unlockPrice;
  final String? currency;

  const _CourseStatus({
    required this.isUnlocked,
    required this.showPriceUnlock,
    this.unlockPrice,
    this.currency,
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
      final label = _formatUnlockLabel(unlockPrice, currency);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2DBD67),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
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

class CourseItem {
  final String id;
  final String title;
  final String subtitle;
  final String imageAsset;
  final String? imageUrl;
  final String? examId;
  final int? questionCount;
  final String? effectivitySheetContent;
  final String? bodyOfKnowledgeContent;
  final bool? isUnlocked;
  final double? unlockPrice;
  final String? currency;

  const CourseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.imageUrl,
    this.examId,
    this.questionCount,
    this.effectivitySheetContent,
    this.bodyOfKnowledgeContent,
    this.isUnlocked,
    this.unlockPrice,
    this.currency,
  });
}

const List<CourseItem> _courses = [
  CourseItem(
    id: 'api510',
    title: 'API 510 - Pressure vessel Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding1.png',
  ),
  CourseItem(
    id: 'api570',
    title: 'API 570 - Piping Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding2.png',
  ),
  CourseItem(
    id: 'api653',
    title: 'API 653 - Aboveground Storage Tanks Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding3.png',
  ),
  CourseItem(
    id: 'api1169',
    title: 'API 1169 - Pipeline Construction Inspector',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding4.png',
  ),
  CourseItem(
    id: 'api936',
    title: 'API 936 - Refractory Personnel',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding1.png',
  ),
  CourseItem(
    id: 'sife',
    title: 'SIFE - Source Inspector Fixed Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding2.png',
  ),
  CourseItem(
    id: 'sire',
    title: 'SIRE - Source Inspector Rotating Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding3.png',
  ),
  CourseItem(
    id: 'siee',
    title: 'SIEE - Source Inspector Electrical Equipment',
    subtitle: 'Master your certification exam',
    imageAsset: 'assets/images/onboarding4.png',
  ),
];
