import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/session.dart';
import '../core/api.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final tr = context.tr;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    size: 38,
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              tr('app'),
                              style: type.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                            Text(tr('tagline'), style: type.titleMedium),
                            const SizedBox(height: 28),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      tr('welcome'),
                                      style: type.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tr('signInHint'),
                                      style: type.bodyMedium,
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: name,
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: tr('loginName'),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                        ),
                                      ),
                                      validator: (value) {
                                        final clean = value?.trim() ?? '';
                                        if (clean.isEmpty) {
                                          return tr('required');
                                        }
                                        return clean.length > 254
                                            ? tr('tooLong')
                                            : null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: password,
                                      obscureText: obscure,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: tr('password'),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: tr(
                                            obscure
                                                ? 'showPassword'
                                                : 'hidePassword',
                                          ),
                                          onPressed: () => setState(
                                            () => obscure = !obscure,
                                          ),
                                          icon: Icon(
                                            obscure
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return tr('required');
                                        }
                                        return utf8.encode(value).length > 72
                                            ? tr('tooLong')
                                            : null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    ActionButton(
                                      label: 'login',
                                      icon: Icons.login,
                                      success: null,
                                      action: () async {
                                        if (!form.currentState!.validate()) {
                                          return;
                                        }
                                        await context.read<Session>().signIn(
                                          name.text.trim(),
                                          password.text,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user!;
    return PageFrame(
      title: 'account',
      child: Collection(
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user['full_name'].toString()),
              subtitle: Text(context.tr(user['role'].toString())),
            ),
          ),
          for (final (label, icon, page) in <(String, IconData, Widget)>[
            ('profile', Icons.badge_outlined, const ProfilePage()),
            ('settings', Icons.settings_outlined, const SettingsPage()),
            ('team', Icons.groups_outlined, const TeamPage()),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(context.tr(label)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              ),
            ),
          const SizedBox(height: 16),
          ActionButton(
            label: 'logout',
            icon: Icons.logout,
            success: null,
            requiresConfirmation: true,
            action: session.signOut,
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user!;
    return PageFrame(
      title: 'profile',
      child: Collection(
        children: [
          for (final key in [
            'full_name',
            'email',
            'username',
            'student_code',
            'role',
          ])
            if (user[key] != null)
              ListTile(
                title: Text(context.tr(key)),
                subtitle: Text(
                  key == 'role'
                      ? context.tr(user[key].toString())
                      : user[key].toString(),
                ),
              ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.tr('edit')),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditFields(
                  title: 'profile',
                  initial: user,
                  fields: const [
                    (key: 'full_name', optional: false, max: 120),
                    (key: 'email', optional: false, max: 254),
                  ],
                  save: (data) async {
                    final profile = await session.api.send(
                      "/users/${user['id']}",
                      method: 'PUT',
                      body: data,
                    ) as Json;
                    if (session.user?['id'] == profile['id']) {
                      session.updateProfile(profile);
                    }
                  },
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_reset),
            label: Text(context.tr('changePassword')),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditFields(
                  title: 'changePassword',
                  fields: const [
                    (key: 'current_password', optional: false, max: 72),
                    (key: 'new_password', optional: false, max: 72),
                  ],
                  save: (data) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final message = context.tr('passwordChanged');
                    await session.api.send(
                      '/auth/change-password',
                      method: 'PUT',
                      body: data,
                    );
                    await session.signOut();
                    if (messenger.mounted) {
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return PageFrame(
      title: 'settings',
      child: Collection(
        children: [
          DropdownButtonFormField<String>(
            initialValue: session.locale.languageCode,
            decoration: InputDecoration(
              labelText: context.tr('language'),
              prefixIcon: const Icon(Icons.language),
            ),
            items: ['vi', 'en']
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(context.tr(code)),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value != null) await session.changeLanguage(value);
            },
          ),
          SwitchListTile(
            title: Text(context.tr('dark')),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: session.theme == ThemeMode.dark,
            onChanged: session.changeTheme,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.tr('about')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: context.tr('app'),
              children: [Text(context.tr('aboutText'))],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(context.tr('team')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'team',
    child: DataPanel<Json>(
      load: () async =>
          jsonDecode(await rootBundle.loadString('assets/team.json')) as Json,
      builder: (context, team, _) {
        final members = rows(team['members']);
        final link = Uri.tryParse(team['github']?.toString() ?? '');
        return Collection(
          children: [
            if (members.isEmpty) ListTile(title: Text(context.tr('teamEmpty'))),
            for (final member in members)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(member['name'].toString()),
                  subtitle: Text(
                    "${context.tr('student_code')}: ${member['student_code']}\n"
                    "${context.tr('role')}: ${member['role_${context.tr.locale.languageCode}']}",
                  ),
                ),
              ),
            if (link != null &&
                link.scheme == 'https' &&
                link.host == 'github.com')
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('GitHub'),
                subtitle: Text(link.toString()),
                onTap: () async {
                  var opened = false;
                  try {
                    opened = await launchUrl(
                      link,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {
                    // Hiển thị lỗi khi thiết bị không có ứng dụng xử lý liên kết.
                  }
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('githubFailed'))),
                    );
                  }
                },
              ),
          ],
        );
      },
    ),
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return PageFrame(
      title: 'notifications',
      child: DataPanel<Json>(
        load: () async {
          final data = await session.api.object('/notifications');
          // Đợi Flutter hoàn tất khung hiện tại trước khi cập nhật huy hiệu toàn cục.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) session.setUnread(countOf(data['unread']));
          });
          return data;
        },
        builder: (context, data, refresh) => Collection(
          onRefresh: refresh,
          children: [
            if (countOf(data['unread']) > 0)
              ListTile(
                title: Text("${context.tr('unread')} · ${data['unread']}"),
              ),
            for (final item in rows(data['items']))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(
                          countOf(item['is_read']) == 0
                              ? Icons.mark_email_unread_outlined
                              : Icons.drafts_outlined,
                        ),
                        title: Text(context.tr(item['kind'].toString())),
                        subtitle: Text(
                          "${item['book_title']}\n${dateOf(context, item['created_at'])}",
                        ),
                      ),
                      if (countOf(item['is_read']) == 0)
                        ActionButton(
                          label: 'markRead',
                          success: null,
                          action: () async {
                            await session.api.send(
                              "/notifications/${item['id']}/read",
                              method: 'PATCH',
                            );
                            refresh();
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
