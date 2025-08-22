import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:product_hunt/model/product_model.dart';
import 'package:product_hunt/model/user_model.dart';
import 'package:product_hunt/services/firebase_service.dart';
import 'package:product_hunt/services/user_service.dart';

class ProductService {
  // Create new product
  static Future<String?> createProduct(ProductModel product) async {
    try {
      // Get creator info
      UserModel? creator = await UserService.getCurrentUserProfile();
      if (creator == null) return null;

      Map<String, dynamic> productData = product.toMap();
      productData['creatorInfo'] = {
        'username': creator.username,
        'displayName': creator.displayName,
        'profilePicture': creator.profilePicture,
      };

      DocumentReference docRef = await FirebaseService.productsRef.add(
        productData,
      );
      return docRef.id;
    } catch (e) {
      print('Error creating product: $e');
      return null;
    }
  }

  // Get product by ID
  static Future<ProductModel?> getProductById(String productId) async {
    try {
      DocumentSnapshot doc = await FirebaseService.productsRef
          .doc(productId)
          .get();
      if (doc.exists) {
        return ProductModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // Get today's products (launched today, sorted by upvotes)
  static Stream<List<ProductModel>> getTodaysProducts() {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1));

    return FirebaseService.productsRef
        .where('status', isEqualTo: 'published')
        .where(
          'launchDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('launchDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('launchDate')
        .orderBy('upvoteCount', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get products by category
  static Stream<List<ProductModel>> getProductsByCategory(String category) {
    return FirebaseService.productsRef
        .where('status', isEqualTo: 'published')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get featured products
  static Stream<List<ProductModel>> getFeaturedProducts() {
    return FirebaseService.productsRef
        .where('status', isEqualTo: 'published')
        .where('isFeatured', isEqualTo: true)
        .orderBy('upvoteCount', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get user's products
  static Stream<List<ProductModel>> getUserProducts(String userId) {
    return FirebaseService.productsRef
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Search products
  static Future<List<ProductModel>> searchProducts(String query) async {
    try {
      query = query.toLowerCase();

      // Search by name
      QuerySnapshot nameResults = await FirebaseService.productsRef
          .where('status', isEqualTo: 'published')
          .get();

      List<ProductModel> products = nameResults.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                product.tagline.toLowerCase().contains(query) ||
                product.description.toLowerCase().contains(query) ||
                product.tags.any((tag) => tag.toLowerCase().contains(query)),
          )
          .toList();

      // Sort by relevance (upvotes for now)
      products.sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));

      return products;
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  // Update product
  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await FirebaseService.productsRef.doc(productId).update(updates);
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  // Delete product
  static Future<void> deleteProduct(String productId) async {
    try {
      // Delete product document
      await FirebaseService.productsRef.doc(productId).delete();

      // Delete subcollections (upvotes, comments)
      await _deleteProductSubcollections(productId);
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  // Helper: Delete product subcollections
  static Future<void> _deleteProductSubcollections(String productId) async {
    try {
      // Delete upvotes
      QuerySnapshot upvotes = await FirebaseService.productsRef
          .doc(productId)
          .collection('upvotes')
          .get();

      for (DocumentSnapshot doc in upvotes.docs) {
        await doc.reference.delete();
      }

      // Delete comments
      QuerySnapshot comments = await FirebaseService.productsRef
          .doc(productId)
          .collection('comments')
          .get();

      for (DocumentSnapshot doc in comments.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting product subcollections: $e');
    }
  }

  // Publish product
  static Future<void> publishProduct(String productId) async {
    try {
      await FirebaseService.productsRef.doc(productId).update({
        'status': 'published',
        'launchDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error publishing product: $e');
      rethrow;
    }
  }

  // Get trending products (last 7 days)
  static Stream<List<ProductModel>> getTrendingProducts() {
    DateTime weekAgo = DateTime.now().subtract(Duration(days: 7));

    return FirebaseService.productsRef
        .where('status', isEqualTo: 'published')
        .where(
          'launchDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo),
        )
        .orderBy('launchDate')
        .orderBy('upvoteCount', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList(),
        );
  }
}
