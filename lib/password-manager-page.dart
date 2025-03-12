import 'package:flutter/material.dart';
import 'credential-manager.dart';

class PasswordManagerPage extends StatefulWidget {
  const PasswordManagerPage({Key? key}) : super(key: key);

  @override
  State<PasswordManagerPage> createState() => _PasswordManagerPageState();
}

class _PasswordManagerPageState extends State<PasswordManagerPage> {
  List<Map<String, dynamic>> _savedCredentials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    setState(() {
      _isLoading = true;
    });

    final credentials = await CredentialManager.getAllCredentials();

    setState(() {
      _savedCredentials = credentials;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Passwords'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSavedCredentials,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _savedCredentials.isEmpty
              ? Center(child: Text('No saved passwords'))
              : ListView.builder(
                itemCount: _savedCredentials.length,
                itemBuilder: (context, index) {
                  final credential = _savedCredentials[index];
                  return Dismissible(
                    key: Key(credential['domain']),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('Delete Password'),
                              content: Text(
                                'Are you sure you want to delete the saved password for ${credential['domain']}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                      );
                    },
                    onDismissed: (direction) async {
                      await CredentialManager.deleteCredentials(
                        credential['domain'],
                      );
                      setState(() {
                        _savedCredentials.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Password for ${credential['domain']} deleted',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Image.network(
                          'https://www.google.com/s2/favicons?domain=${credential['domain']}&sz=64',
                          width: 24,
                          height: 24,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(Icons.web),
                        ),
                      ),
                      title: Text(credential['domain']),
                      subtitle: Text(credential['username']),
                      trailing: Text(
                        'Last used: ${_formatDate(credential['last_used'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
