part of '../watermark_page.dart';

/// Web-only retention handling, legal dialogs and privacy badge.

// -------- Library-level declarations (kept private) --------

/// Web deployment limits: files live in browser memory only, so the
/// session is bounded (5 files, 10 MB each) and erased after 2 minutes
/// of inactivity.
const int _webMaxFiles = 5;
const int _webMaxFileSizeBytes = 10 * 1024 * 1024;
const Duration _webRetentionWindow = Duration(minutes: 2);

extension _WatermarkPageStateWebPart on WatermarkPageState {
  /// (Web only) Countdown banner: files live in browser memory only and are
  /// erased when the retention window elapses.
  Widget _buildWebRetentionBanner(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.webRetentionWarning(_webRetentionRemainingLabel ?? '00:00'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// (Web only) Scrollable dialog for the French legal texts.
  ///
  /// [sections] is a list of (heading, body) pairs; an empty heading renders
  /// the body as a plain paragraph.
  void _showWebLegalDialog(String title, List<(String, String)> sections) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dernière mise à jour : 19 octobre 2026',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 16),
                for (final (heading, body) in sections) ...[
                  if (heading.isNotEmpty) ...[
                    Text(heading, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                  ],
                  Text(body, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  /// (Web only) « Mentions légales » — French legal notice.
  void _showWebMentionsLegales() {
    _showWebLegalDialog('Mentions légales', [
      (
        'Éditeur',
        'Antoine Giniès, personne physique.\n'
            'Domicilié : 31600 Muret, France.\n'
            'Email : antoine@ginies.org'
      ),
      ('Directeur de la publication', 'Antoine Giniès'),
      ('Hébergeur', 'Serveur personnel de l\'éditeur.'),
      (
        'Propriété intellectuelle',
        'Le logiciel SecureMark est publié sous licence GNU GPL-3.0.\n'
            'Le contenu de cette page (textes originaux) appartient à son éditeur.'
      ),
      (
        'Données personnelles',
        'Pour plus d\'informations sur la collecte et l\'utilisation de vos '
            'données personnelles, consultez la page Confidentialité.'
      ),
      (
        'Cookies',
        'SecureMark n\'utilise aucun cookie. Les préférences de '
            'l\'application sont stockées localement dans votre navigateur '
            '(localStorage) et ne sont jamais transmises à un serveur.'
      ),
      (
        'Responsabilité',
        'Le service SecureMark est offert en l\'état et peut être interrompu '
            'à tout moment sans préavis. L\'éditeur ne saurait être tenu '
            'responsable de dommages directs ou indirects liés à l\'utilisation '
            'du service. Les documents traités restent sous la seule '
            'responsabilité de l\'utilisateur.'
      ),
    ]);
  }

  /// (Web only) « Confidentialité » — privacy policy for the web deployment.
  void _showWebConfidentialite() {
    _showWebLegalDialog('Politique de confidentialité', [
      (
        '',
        'SecureMark est une application 100 % locale : vos documents sont '
            'traités directement dans votre navigateur et ne quittent jamais '
            'votre appareil.'
      ),
      (
        '1. Données collectées',
        'Aucune. Aucun compte, aucun profil, aucune transmission de fichier '
            'à un serveur. Le serveur qui diffuse cette application ne reçoit '
            'que les fichiers statiques de l\'application (code, icônes) : il ne '
            'reçoit ni ne conserve jamais vos documents.'
      ),
      (
        '2. Données non collectées',
        'Pas d\'analytics : aucun outil d\'analyse tiers (Google Analytics, '
            'etc.) ni pistage. Pas de partage de données : aucune donnée '
            'n\'est vendue ni transmise à des tiers. Pas de publicité : ni '
            'publicité, ni tracking publicitaire.'
      ),
      (
        '3. Stockage local',
        'Fichiers : les fichiers importés et les fichiers générés sont '
            'conservés uniquement en mémoire volatile de votre navigateur et '
            'sont effacés automatiquement 2 minutes après la dernière '
            'importation ou le dernier traitement. Préférences : les réglages '
            '(langue, options de filigrane, mots de passe de stéganographie et '
            'de ZIP chiffré, identité de signature) sont stockés dans le '
            'localStorage de votre navigateur, sur votre appareil uniquement.'
      ),
      (
        '4. Sécurité',
        'Tout le traitement (filigrane, stéganographie, chiffrement AES-256, '
            'signature Ed25519) s\'exécute localement dans votre navigateur. Les '
            'mots de passe saisis ne quittent jamais votre appareil.'
      ),
      (
        '5. Suppression des données',
        'Les fichiers en mémoire sont effacés automatiquement après 2 '
            'minutes d\'inactivité. Les préférences locales peuvent être '
            'supprimées à tout moment via les fonctions de votre navigateur '
            '(« vider les données de site ») ou le bouton de réinitialisation '
            'de l\'application.'
      ),
      (
        '6. Modifications',
        'Cette politique peut être mise à jour ponctuellement. La date de '
            'dernière mise à jour est affichée en haut de cette page.'
      ),
      (
        '7. Nous contacter',
        'Pour toute question concernant cette politique :\n'
            'antoine@ginies.org\n'
            'Auteur : Antoine Giniès'
      ),
    ]);
  }

  /// (Web only) App-bar badge: nothing is stored on a server, everything is
  /// processed in the browser. Tapping it opens the « Confidentialité » dialog.
  ///
  /// Adaptive: the secondary line drops out on narrow bars, and once even the
  /// headline would be truncated to an ellipsis only the shield remains (the
  /// tooltip carries the message and the tap still works).
  Widget _buildWebPrivacyBadge(ThemeData theme, AppLocalizations l10n) {
    final linkStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final showText = constraints.maxWidth >= 200;
        final showSubline = constraints.maxWidth >= 400;
        // The badge lives in an Expanded (tight width) in the app bar. Align
        // relaxes that to a loose constraint and the min-sized Row shrinks to
        // the icon + text, so the InkWell tap target is only the content —
        // not the whole remaining bar width.
        return Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: l10n.privacyPolicy,
            child: InkWell(
              onTap: _showWebConfidentialite,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 18, color: theme.colorScheme.primary),
                    if (showText) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.webPrivacyBadgeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (showSubline)
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      l10n.webPrivacyBadgeSub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: theme.hintColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // French-only on purpose, like the footer
                                  // links: the French text is the official
                                  // legal version.
                                  Text('(Confidentialité)', style: linkStyle),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// (Web only) (Re)starts the 2-minute in-memory retention window.
  ///
  /// On the web, picked and generated files exist only in browser memory
  /// (WebFileStore). So that sensitive data cannot linger indefinitely in a
  /// shared browser, all file data is erased 2 minutes after the last pick
  /// or processing run.
  void _webStartRetentionWindow() {
    if (!kIsWeb) return;
    _webRetentionDeadline = DateTime.now().add(_webRetentionWindow);
    _webRetentionTimer?.cancel();
    _webRetentionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final deadline = _webRetentionDeadline;
      if (deadline == null) return;
      if (deadline.isBefore(DateTime.now())) {
        _webEraseData();
      } else {
        // Refresh the countdown shown in the retention banner.
        _refresh(() {});
      }
    });
  }

  /// (Web only) Erases all in-memory file data (picked + generated).
  void _webEraseData() {
    _webRetentionTimer?.cancel();
    _webRetentionTimer = null;
    _webRetentionDeadline = null;
    WebFileStore.clear();
    _addLog('In-memory files erased after the 2-minute retention window.');
    if (!mounted) return;
    _refresh(() {
      _selectedPaths = <String>[];
      _processedFiles = <ProcessedFile>[];
      _previewIndex = 0;
      _rawImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.webDataExpired),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// (Web only) Countdown text for the retention banner (mm:ss).
  String? get _webRetentionRemainingLabel {
    final deadline = _webRetentionDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
