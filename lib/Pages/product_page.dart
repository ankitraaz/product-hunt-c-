import 'dart:typed_data'; // <-- for Uint8List (web+mobile safe)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // ✅ Firestore path: product (singular) — matches your rules
  final CollectionReference products = FirebaseFirestore.instance.collection(
    'product',
  );

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  // ---- Image state (web-safe) ----
  XFile? _pickedImage;
  Uint8List? _imageBytes; // preview + upload ke liye

  // -------- Helpers --------
  double? _parsePrice(String raw) {
    if (raw.trim().isEmpty) return null;
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[₹$, ]'), '');
    s = s.replaceAll(',', '');
    if (s.endsWith('k')) {
      final base = double.tryParse(s.substring(0, s.length - 1));
      return base == null ? null : base * 1000;
    }
    if (s.endsWith('m')) {
      final base = double.tryParse(s.substring(0, s.length - 1));
      return base == null ? null : base * 1000000;
    }
    return double.tryParse(s);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // -------- Image pick & upload (multi-platform) --------
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes(); // works on web + mobile
      setState(() {
        _pickedImage = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<String> _uploadPickedBytes() async {
    if (_imageBytes == null) return '';
    final ext = (_pickedImage?.name.toLowerCase().split('.').last ?? 'jpg');
    final ref = FirebaseStorage.instance.ref(
      'product_images/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );

    await ref.putData(
      _imageBytes!,
      SettableMetadata(contentType: 'image/$ext'),
    );
    return ref.getDownloadURL();
  }

  // -------- CRUD --------
  Future<void> _addProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('You must be logged in to add a product.');
      return;
    }

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final parsedPrice = _parsePrice(_priceController.text);

    if (name.isEmpty) {
      _toast('Name is required.');
      return;
    }
    if (parsedPrice == null) {
      _toast('Please enter a valid price (e.g., 21000, 21k, ₹21,000).');
      return;
    }

    String imageUrl = '';
    if (_imageBytes != null) {
      imageUrl = await _uploadPickedBytes();
    }

    await products.add({
      'name': name,
      'description': desc,
      'price': parsedPrice,
      'imageUrl': imageUrl,
      'voteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid, // 🔴 rules ke liye must
    });

    _nameController.clear();
    _descController.clear();
    _priceController.clear();
    setState(() {
      _pickedImage = null;
      _imageBytes = null;
    });
  }

  Future<void> _updateProduct(String id, String currentImageUrl) async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final parsedPrice = _parsePrice(_priceController.text);

    if (name.isEmpty) {
      _toast('Name is required.');
      return;
    }
    if (parsedPrice == null) {
      _toast('Please enter a valid price (e.g., 21000, 21k, ₹21,000).');
      return;
    }

    String imageUrl = currentImageUrl;
    if (_imageBytes != null) {
      imageUrl = await _uploadPickedBytes();
    }

    await products.doc(id).update({
      'name': name,
      'description': desc,
      'price': parsedPrice,
      'imageUrl': imageUrl,
      // createdBy immutable per rules
    });
  }

  Future<void> _deleteProduct(String id) async {
    await products.doc(id).delete();
  }

  // -------- Voting (unique per user) --------
  Future<void> _upvote(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _toast('Please sign in to vote.');
      return;
    }

    final productRef = products.doc(productId);
    final voteRef = productRef.collection('vote').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      if (voteSnap.exists) return; // already voted

      // ✅ Add vote record
      tx.set(voteRef, {
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Read current vote count to match rules
      final productSnap = await tx.get(productRef);
      final data = productSnap.data() as Map<String, dynamic>?; // Cast to Map
      final currentVotes = (data?['voteCount'] ?? 0) as int;
      tx.update(productRef, {'voteCount': currentVotes + 1});
    });
  }

  // -------- Users/Comments --------
  Future<String> _fetchUsername(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String name = (doc.data()?['username'] ?? '').toString().trim();

      // ✅ Fallback to displayName or 'Anonymous'
      if (name.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        name = user?.displayName?.trim() ?? 'Anonymous';
      }

      return name;
    } catch (_) {
      return 'Anonymous';
    }
  }

  Future<void> _addComment(String productId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Please sign in to comment.');
      return;
    }
    final t = text.trim();
    if (t.isEmpty) return;

    final username = await _fetchUsername(user.uid);

    await products.doc(productId).collection('comment').add({
      'text': t,
      'userId': user.uid,
      'username': username, // ✅ always set
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _openCommentsSheet(String productId) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live comments list
              SizedBox(
                height: 320,
                child: StreamBuilder<QuerySnapshot>(
                  stream: products
                      .doc(productId)
                      .collection('comment')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text('Failed to load comments'),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Be first!'),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final m = docs[i].data() as Map<String, dynamic>? ?? {};
                        final text = (m['text'] ?? '').toString();
                        final userId = (m['userId'] ?? '').toString();
                        final uname = (m['username'] ?? '').toString();
                        final ts = m['createdAt'];
                        final when = ts is Timestamp ? ts.toDate() : null;

                        final who = uname.isNotEmpty
                            ? '@$uname'
                            : (userId.isNotEmpty ? '@$userId' : '');

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.comment, size: 18),
                          title: Text(text),
                          subtitle: Text(
                            '${who.isNotEmpty ? '$who · ' : ''}'
                            '${when != null ? when.toLocal().toString() : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await _addComment(productId, controller.text);
                      controller.clear();
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  // -------- Dialog --------
  void _showDialog({String? id, String? currentImageUrl}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,kKmM₹$ ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price (e.g., 21000 / 21k / ₹21,000)',
                ),
              ),
              const SizedBox(height: 10),
              _imageBytes != null
                  ? Image.memory(_imageBytes!, height: 100)
                  : (currentImageUrl != null && currentImageUrl.isNotEmpty)
                  ? Image.network(currentImageUrl, height: 100)
                  : const Text('No image selected'),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                _toast('Please sign in first.');
                return;
              }
              if (id == null) {
                await _addProduct();
              } else {
                await _updateProduct(id, currentImageUrl ?? '');
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products CRUD')),
      body: StreamBuilder<QuerySnapshot>(
        stream: products.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.docs;
          if (data.isEmpty) {
            return const Center(child: Text('No products yet. Add one!'));
          }

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final doc = data[index];
              final map = doc.data() as Map<String, dynamic>? ?? {};

              final name = (map['name'] ?? '').toString();
              final desc = (map['description'] ?? '').toString();
              final priceAny = map['price'];
              final priceStr = priceAny == null ? '—' : priceAny.toString();
              final imageUrl = (map['imageUrl'] ?? '').toString();
              final voteCnt = (map['voteCount'] ?? map['votes'] ?? 0) as num;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desc.isNotEmpty) Text(desc),
                      Text('₹$priceStr'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.thumb_up),
                            onPressed: () => _upvote(doc.id),
                            tooltip: 'Upvote',
                          ),
                          Text('${voteCnt.toInt()} votes'),
                          TextButton.icon(
                            onPressed: () => _openCommentsSheet(doc.id),
                            icon: const Icon(Icons.comment),
                            label: const Text('Comments'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _nameController.text = name;
                          _descController.text = desc;
                          _priceController.text = priceAny == null
                              ? ''
                              : priceAny.toString();
                          _imageBytes = null; // reset picker
                          _pickedImage = null;
                          _showDialog(id: doc.id, currentImageUrl: imageUrl);
                        },
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteProduct(doc.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _nameController.clear();
          _descController.clear();
          _priceController.clear();
          _imageBytes = null;
          _pickedImage = null;
          _showDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
