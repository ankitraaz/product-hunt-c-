// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class ProductService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   /// Increment vote count by 1
//   Future<void> upvoteProduct(String productId) async {
//     final user = _auth.currentUser;
//     if (user == null) throw Exception("User not signed in");

//     final productRef = _firestore.collection('product').doc(productId);

//     await _firestore.runTransaction((transaction) async {
//       final snapshot = await transaction.get(productRef);
//       if (!snapshot.exists) throw Exception("Product not found");

//       final currentVotes = snapshot.get('voteCount') ?? 0;
//       transaction.update(productRef, {'voteCount': currentVotes + 1});
//     });
//   }

//   /// Add comment with username
//   Future<void> addComment(String productId, String commentText) async {
//     final user = _auth.currentUser;
//     if (user == null) throw Exception("User not signed in");

//     // Fetch username either from displayName or users collection
//     String username = user.displayName ?? '';
//     if (username.isEmpty) {
//       final userDoc = await _firestore.collection('users').doc(user.uid).get();
//       username = userDoc.data()?['username'] ?? 'Anonymous';
//     }

//     await _firestore
//         .collection('product')
//         .doc(productId)
//         .collection('comment')
//         .add({
//           'userId': user.uid,
//           'username': username,
//           'text': commentText,
//           'createdAt': FieldValue.serverTimestamp(),
//         });
//   }
// }
