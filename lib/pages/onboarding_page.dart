import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  final bool hasCamera;

  const OnboardingPage(
      {super.key, required this.onDone, this.hasCamera = true});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final pages = [
      _OnboardingFeaturesSlide(
        title: l10n.appTitle,
        features: [
          _FeatureItem(
            title: l10n.onboardingPage1Title,
            body: l10n.onboardingPage1Body,
            icon: Icons.security,
            color: Colors.blue,
          ),
          _FeatureItem(
            title: l10n.onboardingPage2Title,
            body: l10n.onboardingPage2Body,
            icon: Icons.visibility_off,
            color: Colors.green,
          ),
          _FeatureItem(
            title: l10n.onboardingPage3Title,
            body: l10n.onboardingPage3Body,
            icon: Icons.auto_awesome,
            color: Colors.purple,
          ),
          _FeatureItem(
            title: l10n.qrWatermarkTitle,
            body: l10n.onboardingQrCodeNote,
            icon: Icons.qr_code_2,
            color: Colors.orange,
          ),
        ],
      ),
      _OnboardingStepSlide(
        title: l10n.onboardingStepTitle,
        steps: [
          l10n.onboardingStep1,
          widget.hasCamera
              ? l10n.onboardingStep2
              : l10n.onboardingStep2NoCamera,
          l10n.onboardingStep3,
          l10n.onboardingStep4,
        ],
        images: [
          'images/guide/save_profile.png',
          if (widget.hasCamera) 'images/guide/import.png',
          'images/guide/apply.png',
          'images/guide/share.png',
        ],
      ),
      _OnboardingExpertSlide(
        title: l10n.onboardingExpertTitle,
        cards: [
          _ExpertCardData(
            title: l10n.onboardingExpertModeTitle,
            body: l10n.onboardingExpertNote,
            icon: Icons.settings,
            isHighlight: true,
          ),
          _ExpertCardData(
            title: l10n.onboardingSaveProfileTitle,
            body: l10n.onboardingProfileSave,
            icon: Icons.save_outlined,
            image: 'images/guide/save_profile.png',
          ),
          _ExpertCardData(
            title: l10n.onboardingLiveStatusTitle,
            body: l10n.onboardingOptionsNote,
            icon: Icons.settings_input_component_outlined,
            image: 'images/guide/enabled_options.png',
          ),
          _ExpertCardData(
            title: l10n.onboardingFileAnalyzerTitle,
            body: l10n.onboardingFileAnalyzerNote,
            icon: Icons.search_rounded,
            image: 'images/guide/file_analyser.png',
          ),
        ],
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return pages[index];
            },
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: widget.onDone,
                  child: Text(l10n.onboardingSkip),
                ),
                Row(
                  children: List.generate(
                    pages.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      widget.onDone();
                    }
                  },
                  child: Text(
                    _currentPage == pages.length - 1
                        ? l10n.onboardingDone
                        : l10n.onboardingNext,
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

class _FeatureItem {
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  _FeatureItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
}

class _OnboardingFeaturesSlide extends StatelessWidget {
  final String title;
  final List<_FeatureItem> features;

  const _OnboardingFeaturesSlide({
    required this.title,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: features.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final feature = features[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: feature.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature.icon,
                        size: 28,
                        color: feature.color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feature.body,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepSlide extends StatelessWidget {
  final String title;
  final List<String> steps;
  final List<String> images;

  const _OnboardingStepSlide({
    required this.title,
    required this.steps,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildStepList(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepList(ThemeData theme) {
    List<Widget> children = [];
    for (int i = 0; i < steps.length; i++) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i].replaceFirst(RegExp(r'^\d+\.\s+'), ''),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (i < images.length) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: Image.asset(
                  images[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }
    }
    return children;
  }
}

class _ExpertCardData {
  final String title;
  final String body;
  final IconData icon;
  final String? image;
  final bool isHighlight;

  _ExpertCardData({
    required this.title,
    required this.body,
    required this.icon,
    this.image,
    this.isHighlight = false,
  });
}

class _OnboardingExpertSlide extends StatelessWidget {
  final String title;
  final List<_ExpertCardData> cards;

  const _OnboardingExpertSlide({
    required this.title,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final card = cards[index];
                return _buildExpertCard(theme, card);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertCard(ThemeData theme, _ExpertCardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.isHighlight
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isHighlight
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon,
                  size: 20,
                  color: data.isHighlight
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary),
              const SizedBox(width: 12),
              Text(
                data.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: data.isHighlight ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: theme.textTheme.bodySmall,
          ),
          if (data.image != null) ...[
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: Image.asset(
                    data.image!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
