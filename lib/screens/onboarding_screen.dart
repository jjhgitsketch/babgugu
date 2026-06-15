// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final Set<String> _selectedTags = {};

  int _currentPage = 0;
  int _age = 20;
  String? _gender;
  bool _loading = false;

  bool get _profileReady =>
      _nameController.text.trim().isNotEmpty && _gender != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshProfileState);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.removeListener(_refreshProfileState);
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _refreshProfileState() {
    if (mounted) setState(() {});
  }

  void _nextPage() {
    if (_currentPage == 1 && !_profileReady) return;
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _goBack() async {
    if (_currentPage > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
      return;
    }
    await SupabaseService.signOut();
  }

  Future<void> _finish() async {
    if (_selectedTags.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        throw Exception('\uB85C\uADF8\uC778\uC774 \uD544\uC694\uD574\uC694');
      }

      final nickname = _nicknameController.text.trim();
      final user = UserModel(
        id: authUser.id,
        name: _nameController.text.trim(),
        nickname: nickname.isEmpty ? null : nickname,
        tags: _selectedTags.toList(),
        age: _age,
        gender: _gender,
      );
      currentUser = user;
      await SupabaseService.saveUser(user);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\uC624\uB958: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _WelcomePage(onBack: _goBack, onNext: _nextPage),
            _ProfilePage(
              nameController: _nameController,
              nicknameController: _nicknameController,
              age: _age,
              gender: _gender,
              canContinue: _profileReady,
              onGenderChanged: (value) => setState(() => _gender = value),
              onAgeChanged: (value) => setState(() => _age = value),
              onBack: _goBack,
              onNext: _nextPage,
            ),
            _TagPage(
              selectedTags: _selectedTags,
              onToggle: (tag) => setState(() {
                _selectedTags.contains(tag)
                    ? _selectedTags.remove(tag)
                    : _selectedTags.add(tag);
              }),
              onBack: _goBack,
              onDone: _finish,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OnboardingBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        color: Colors.black,
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _WelcomePage({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        children: [
          _OnboardingBackButton(onTap: onBack),
          const SizedBox(height: 38),
          Center(
            child: Image.asset(
              'assets/images/babgugu_logo.png',
              width: 122,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '\uD63C\uBC25\uC740 \uC774\uC81C \uADF8\uB9CC\u{1F44D}\n\uB098\uC640 \uC798 \uB9DE\uB294 \uC0AC\uB78C\uACFC \uD568\uAED8 \uBA39\uC5B4\uC694!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF9A9A9A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 78),
          const _FeatureRow(
            emoji: '\u{1F3AF}',
            text:
                '\uC74C\uC2DD \uCDE8\uD5A5, \uAD00\uC2EC\uC0AC \uAE30\uBC18 \uBAA8\uC784 \uB9E4\uCE6D',
          ),
          const SizedBox(height: 23),
          const _FeatureRow(
            emoji: '\u{1F35C}',
            text: '\uC2DD\uB2F9 \uBAA8\uC784 & \uBC30\uB2EC \uBAA8\uC784',
          ),
          const SizedBox(height: 23),
          const _FeatureRow(
            emoji: '\u{1F4AC}',
            text:
                '\uC2E4\uC2DC\uAC04 \uCC44\uD305 & \uB354\uCE58\uD398\uC774 \uACC4\uC0B0',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '\uD504\uB85C\uD544 \uC124\uC815\uD558\uAE30',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _FeatureRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            emoji,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController nicknameController;
  final int age;
  final String? gender;
  final bool canContinue;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<int> onAgeChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ProfilePage({
    required this.nameController,
    required this.nicknameController,
    required this.age,
    required this.gender,
    required this.canContinue,
    required this.onGenderChanged,
    required this.onAgeChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OnboardingBackButton(onTap: onBack),
                  const SizedBox(height: 42),
                  const Text(
                    '\uAE30\uBCF8 \uC815\uBCF4\uB97C \uC54C\uB824\uC8FC\uC138\uC694',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 68),
                  const _FieldLabel('\uC774\uB984'),
                  const SizedBox(height: 8),
                  _OnboardingInput(
                    controller: nameController,
                    hintText: '\uC785\uB825\uD574\uC8FC\uC138\uC694',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(
                    '\uB2C9\uB124\uC784',
                    trailing: '(\uC120\uD0DD)',
                  ),
                  const SizedBox(height: 8),
                  _OnboardingInput(
                    controller: nicknameController,
                    hintText: '\uC785\uB825\uD574\uC8FC\uC138\uC694',
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    '\uC124\uC815\uD558\uC9C0 \uC54A\uC73C\uBA74 \uC774\uB984\uC73C\uB85C \uD45C\uC2DC\uB3FC\uC694',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8F8F8F)),
                  ),
                  const SizedBox(height: 26),
                  const _FieldLabel('\uC131\uBCC4'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _GenderButton(
                          label: '\uB0A8',
                          selected: gender == '\uB0A8',
                          onTap: () => onGenderChanged('\uB0A8'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GenderButton(
                          label: '\uC5EC',
                          selected: gender == '\uC5EC',
                          onTap: () => onGenderChanged('\uC5EC'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 23),
                  Text(
                    '\uB098\uC774 : $age\uC138',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFFD9D9D9),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
                      tickMarkShape:
                          const RoundSliderTickMarkShape(tickMarkRadius: 2),
                      activeTickMarkColor: AppColors.primary,
                      inactiveTickMarkColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: age.toDouble(),
                      min: 18,
                      max: 40,
                      divisions: 22,
                      onChanged: (value) => onAgeChanged(value.round()),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: canContinue ? onNext : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: const Color(0xFFD9D9D9),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '\uB2E4\uC74C',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final String? trailing;

  const _FieldLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
        children: [
          if (trailing != null)
            TextSpan(
              text: trailing,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8F8F8F),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputAction textInputAction;

  const _OnboardingInput({
    required this.controller,
    required this.hintText,
    required this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: TextField(
        controller: controller,
        textInputAction: textInputAction,
        scrollPadding: const EdgeInsets.only(bottom: 260),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFC6C6C6), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _TagPage extends StatelessWidget {
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;
  final VoidCallback onBack;
  final VoidCallback onDone;
  final bool loading;

  const _TagPage({
    required this.selectedTags,
    required this.onToggle,
    required this.onBack,
    required this.onDone,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final categories = {
      '\uB300\uD654 \uC2A4\uD0C0\uC77C': [
        '#\uC870\uC6A9\uD55C \uB300\uD654',
        '#\uD65C\uBC1C\uD55C \uB300\uD654',
        '#\uB9D0\uB9CE',
        '#\uD63C\uBC25',
        '#\uBD84\uBC25',
      ],
      '\uC74C\uC2DD \uCDE8\uD5A5': [
        '#\uD55C\uC2DD',
        '#\uC911\uC2DD',
        '#\uC77C\uC2DD',
        '#\uBD84\uC2DD',
        '#\uC591\uC2DD',
        '#\uCC1C\u00B7\uD0D5',
        '#\uC544\uC2DC\uC548',
        '#\uCE58\uD0A8',
        '#\uC57C\uC2DD',
        '#\uACE0\uAE30',
        '#\uD328\uC2A4\uD2B8\uD478\uB4DC',
        '#\uB514\uC800\uD2B8',
        '#\uCC44\uC2DD',
        '#\uB9E4\uC6B4 \uC74C\uC2DD',
      ],
      '\uAD00\uC2EC\uC0AC': [
        '#\uCF54\uB529',
        '#\uC6B4\uB3D9',
        '#\uC5EC\uD589',
        '#\uB3C5\uC11C',
        '#\uC601\uD654',
        '#\uC0AC\uC9C4',
        '#\uB300\uD559\uC0DD',
      ],
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingBackButton(onTap: onBack),
          const SizedBox(height: 26),
          const Text(
            '\uB098\uB97C \uD45C\uD604\uD558\uB294\n\uD0DC\uADF8\uB97C \uACE8\uB77C\uC8FC\uC138\uC694',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${selectedTags.length}\uAC1C \uC120\uD0DD\uB428',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 21),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 11),
                            Wrap(
                              spacing: 7,
                              runSpacing: 8,
                              children: entry.value
                                  .map(
                                    (tag) => TagChip(
                                      tag: tag,
                                      isSelected: selectedTags.contains(tag),
                                      onTap: () => onToggle(tag),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: selectedTags.isNotEmpty && !loading ? onDone : null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: const Color(0xFFD9D9D9),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '\uBC25\uAD6C\uAD6C \uC2DC\uC791\uD558\uAE30',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
