import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// Import your API service
import 'services/api_service.dart';
import 'services/image_service.dart';
import 'AuctionDetailScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

// Enhanced App State Management
class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String _currentLanguage = 'en';

  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void changeLanguage(String language) {
    _currentLanguage = language;
    notifyListeners();
  }
}

class Bid {
  final String id;
  final String productId;
  final String userId;
  final String username;
  final double amount;
  final DateTime createdAt;
  final String? productName;
  final String? imageUrl;

  Bid({
    required this.id,
    required this.productId,
    required this.userId,
    required this.username,
    required this.amount,
    required this.createdAt,
    this.productName,
    this.imageUrl,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'].toString(),
      productId: json['productId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username'] ?? '',
      amount: json['amount'] is String
          ? double.parse(json['amount'])
          : (json['amount'] as num).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      productName: json['productName'],
      imageUrl: json['imageUrl'],
    );
  }
}

// Enhanced Product Model
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isFavorite;
  final int userId;
  final String? username;
  final bool isAuction;
  final double? startingPrice;
  final double? currentBid;
  final DateTime? auctionEnd;
  final int? bidCount;
  final String? highestBidderName;
  final int? timeLeft; // in seconds

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.createdAt,
    required this.isFavorite,
    required this.userId,
    this.username,
    this.isAuction = false,
    this.startingPrice,
    this.currentBid,
    this.auctionEnd,
    this.bidCount = 0,
    this.highestBidderName,
    this.timeLeft,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';

    return Product(
      id: id,
      name: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] is String
          ? double.parse(json['price'])
          : (json['price'] as num?)?.toDouble() ??
                (json['currentPrice'] as num?)?.toDouble() ??
                0,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isFavorite: json['isFavorite'] ?? false,
      userId: json['userId'] ?? 0,
      username: json['username'] ?? json['seller_name'],
      isAuction: json['isAuction'] ?? false,
      startingPrice: (json['startingPrice'] as num?)?.toDouble(),
      currentBid: (json['currentBid'] as num?)?.toDouble(),
      auctionEnd: json['auctionEnd'] != null
          ? DateTime.parse(json['auctionEnd'])
          : null,
      bidCount: json['bidCount'] ?? json['total_bids'] ?? 0,
      highestBidderName: json['highestBidderName'],
      timeLeft: json['timeLeft'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite,
    'userId': userId,
    'username': username,
    'isAuction': isAuction,
    'startingPrice': startingPrice,
    'currentBid': currentBid,
    'auctionEnd': auctionEnd?.toIso8601String(),
    'bidCount': bidCount,
    'highestBidderName': highestBidderName,
    'timeLeft': timeLeft,
  };
}

// User Model
class User {
  final String username;
  final String passwordHash;
  final String? profileImage;

  User({required this.username, required this.passwordHash, this.profileImage});

  Map<String, dynamic> toJson() => {
    'username': username,
    'passwordHash': passwordHash,
    'profileImage': profileImage,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    username: json['username'],
    passwordHash: json['passwordHash'],
    profileImage: json['profileImage'],
  );
}

// Enhanced Authentication Service (now using backend)
class AuthService {
  // Hash password using SHA-256
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.login(username: username, password: password);
  }

  static Future<Map<String, dynamic>> signup(
    String username,
    String password,
  ) async {
    return await ApiService.register(username: username, password: password);
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('currentUser');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }

    // If no local user, check if we have a token
    final token = await ApiService.getToken();
    final username = prefs.getString('username');

    if (token != null && username != null) {
      return User(username: username, passwordHash: '', profileImage: null);
    }

    return null;
  }

  static Future<void> logout() async {
    await ApiService.logout();
  }
}

// Enhanced Product Service (now using backend with local fallback)
class ProductService {
  static Future<List<Product>> getProducts() async {
    try {
      // First try to get from backend
      final productsData = await ApiService.getProducts();

      // Convert to Product objects
      final products = productsData.map((productJson) {
        return Product.fromJson(productJson);
      }).toList();

      // Save a copy locally for offline access
      await _saveProductsLocally(products);

      return products;
    } catch (e) {
      print('Backend error, loading local products: $e');
      // Fallback to local storage
      return await _getLocalProducts();
    }
  }

  static Future<List<Product>> _getLocalProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('products') ?? '[]';
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Product.fromJson(json)).toList();
  }

  static Future<void> _saveProductsLocally(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = products.map((product) => product.toJson()).toList();
    await prefs.setString('products', jsonEncode(jsonList));
  }

  static Future<void> addProduct(Product product) async {
    try {
      // Send to backend
      final result = await ApiService.addProduct(
        name: product.name,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
      );

      if (result['success'] == true) {
        // Also save locally
        final products = await _getLocalProducts();
        products.add(product);
        await _saveProductsLocally(products);
      } else {
        throw Exception('Failed to add product to backend');
      }
    } catch (e) {
      print('Backend add failed, saving locally: $e');
      // Save locally if backend fails
      final products = await _getLocalProducts();
      products.add(product);
      await _saveProductsLocally(products);
    }
  }

  static Future<void> deleteProduct(String productId) async {
    try {
      // Try to delete from backend
      await ApiService.deleteProduct(int.parse(productId));
    } catch (e) {
      print('Backend delete failed: $e');
    }

    // Always delete locally
    final products = await _getLocalProducts();
    products.removeWhere((product) => product.id == productId);
    await _saveProductsLocally(products);
  }

  static Future<void> toggleFavorite(String productId) async {
    try {
      final products = await _getLocalProducts();
      final index = products.indexWhere((product) => product.id == productId);
      if (index != -1) {
        final newFavoriteStatus = !products[index].isFavorite;

        // Update backend
        await ApiService.toggleFavorite(
          productId: int.parse(productId),
          isFavorite: newFavoriteStatus,
        );

        // Update local copy
        products[index] = Product(
          id: products[index].id,
          name: products[index].name,
          description: products[index].description,
          price: products[index].price,
          imageUrl: products[index].imageUrl,
          createdAt: products[index].createdAt,
          isFavorite: newFavoriteStatus,
          userId: products[index].userId,
          username: products[index].username,
        );
        await _saveProductsLocally(products);
      }
    } catch (e) {
      print('Toggle favorite error: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Antika - Modern Marketplace",
      theme: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF6200EE),
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 4,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 4,
        ),
      ),
      home: FutureBuilder<bool>(
        future: ApiService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          if (snapshot.hasData && snapshot.data == true) {
            return const HomePage();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}

/* ---------------- SPLASH SCREEN ----------------- */
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    // Test backend connection
    final isConnected = await ApiService.testConnection();

    if (!isConnected) {
      _showConnectionError();
    }
  }

  void _showConnectionError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text(
            'Cannot connect to server. Make sure Java backend is running.\n\n'
            '1. Start Java backend first\n'
            '2. Check if backend is running at: http://10.0.2.2:8082\n'
            '3. Try again',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6200EE),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FlutterLogo(size: 100),
            const SizedBox(height: 20),
            const Text(
              "Antika",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Modern Marketplace",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: ApiService.testConnection(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container();
                }

                if (snapshot.hasData && snapshot.data == true) {
                  return const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Connected to backend",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  );
                } else {
                  return const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Backend not connected",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- ENHANCED LOGIN PAGE ----------------- */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _backendConnected = true;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
  }

  Future<void> _checkBackendConnection() async {
    final isConnected = await ApiService.testConnection();
    setState(() {
      _backendConnected = isConnected;
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await AuthService.login(
        usernameController.text,
        passwordController.text,
      );

      if (result['success'] == true) {
        // Save user locally
        final prefs = await SharedPreferences.getInstance();
        final user = User(
          username: usernameController.text,
          passwordHash: AuthService.hashPassword(passwordController.text),
        );
        await prefs.setString('currentUser', jsonEncode(user.toJson()));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Invalid credentials"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend connection status
              if (!_backendConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Backend not connected. Login will use local storage.',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _checkBackendConnection,
                        tooltip: 'Retry connection',
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'images/login.png',
                  height: 180,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shopping_bag,
                    size: 100,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Welcome Back 👋",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Login to your account",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: usernameController,
                      label: "Username",
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter username";
                        }
                        if (value.length < 3) {
                          return "Username must be at least 3 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[400])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "or continue with",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(Icons.g_mobiledata, Colors.red),
                        const SizedBox(width: 16),
                        _buildSocialButton(Icons.facebook, Colors.blue),
                        const SizedBox(width: 16),
                        _buildSocialButton(Icons.apple, Colors.black),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[700]),
                      children: const [
                        TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText ? _obscurePassword : false,
      validator: validator,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/* ---------------- ENHANCED SIGN-UP PAGE ----------------- */
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _backendConnected = true;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
  }

  Future<void> _checkBackendConnection() async {
    final isConnected = await ApiService.testConnection();
    setState(() {
      _backendConnected = isConnected;
    });
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Passwords do not match"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final result = await AuthService.signup(
        usernameController.text,
        passwordController.text,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Account created successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Registration failed"),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend status
              if (!_backendConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Backend not connected. Account will be saved locally.',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              Text(
                "Join Antika Today ✨",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create your account to start shopping",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: usernameController,
                      label: "Username",
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Username is required";
                        }
                        if (value.length < 3) {
                          return "Username must be at least 3 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Password is required";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: confirmPasswordController,
                      label: "Confirm Password",
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please confirm your password";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const TermsAndConditions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }
}

/* ---------------- TERMS AND CONDITIONS ----------------- */
class TermsAndConditions extends StatelessWidget {
  const TermsAndConditions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          "By creating an account, you agree to our",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                // Navigate to terms page
              },
              child: Text(
                "Terms of Service",
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text("and", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                // Navigate to privacy policy
              },
              child: Text(
                "Privacy Policy",
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* ---------------- ENHANCED HOME PAGE ----------------- */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  late Future<List<Product>> _productsFuture;
  List<Product> _filteredProducts = [];
  String _selectedCategory = 'All';
  bool _showFavoritesOnly = false;
  bool _backendConnected = true;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _productsFuture = ProductService.getProducts();
    searchController.addListener(_onSearchChanged);
  }

  Future<void> _checkBackendConnection() async {
    final isConnected = await ApiService.testConnection();
    setState(() {
      _backendConnected = isConnected;
    });
  }

  void _onSearchChanged() {
    _filterProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = ProductService.getProducts();
    });
  }

  void _filterProducts() {
    _productsFuture.then((products) {
      final filtered = products.where((product) {
        final searchTerm = searchController.text.toLowerCase();
        final matchesSearch =
            searchTerm.isEmpty ||
            product.name.toLowerCase().contains(searchTerm) ||
            product.description.toLowerCase().contains(searchTerm) ||
            product.price.toString().contains(searchTerm);

        final matchesCategory =
            _selectedCategory == 'All' ||
            product.name.toLowerCase().contains(
              _selectedCategory.toLowerCase(),
            );

        final matchesFavorites = !_showFavoritesOnly || product.isFavorite;

        return matchesSearch && matchesCategory && matchesFavorites;
      }).toList();

      setState(() {
        _filteredProducts = filtered;
      });
    });
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filter Products",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text("Show Favorites Only"),
                value: _showFavoritesOnly,
                onChanged: (value) {
                  setState(() => _showFavoritesOnly = value);
                  _filterProducts();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              const Text("Categories"),
              Wrap(
                spacing: 8,
                children: ['All', 'Electronics', 'Clothing', 'Books', 'Home']
                    .map((category) {
                      return FilterChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() => _selectedCategory = category);
                          _filterProducts();
                          Navigator.pop(context);
                        },
                      );
                    })
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProductDetails(Product product) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                Image.network(
                  product.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(product.description, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text(
                "Price: \$${product.price.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              if (product.username != null)
                Text(
                  "Seller: ${product.username!}",
                  style: const TextStyle(color: Colors.blue),
                ),
              const SizedBox(height: 8),
              Text(
                "Added: ${DateFormat('MMM dd, yyyy').format(product.createdAt)}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              product.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () async {
              await ProductService.toggleFavorite(product.id);
              _refreshProducts();
              Navigator.pop(context);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    _selectedImageFile = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add New Product"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Product Name *",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Price *",
                      prefixText: "\$ ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Image Picker Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Product Image",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: () async {
                                    final image =
                                        await ImageService.pickImageFromCamera();
                                    if (image != null) {
                                      setState(
                                        () => _selectedImageFile = image,
                                      );
                                    }
                                  },
                                  tooltip: 'Take Photo',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.photo_library),
                                  onPressed: () async {
                                    final image =
                                        await ImageService.pickImageFromGallery();
                                    if (image != null) {
                                      setState(
                                        () => _selectedImageFile = image,
                                      );
                                    }
                                  },
                                  tooltip: 'Choose from Gallery',
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (_selectedImageFile != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedImageFile!.path.split('/').last,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No image selected',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      priceController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final price = double.tryParse(priceController.text) ?? 0;
                  if (price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid price'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    String? imageUrl;

                    // If image is selected, use file path as URL (for local testing)
                    if (_selectedImageFile != null) {
                      imageUrl = _selectedImageFile!.path;
                    }

                    final product = Product(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      description: descController.text,
                      price: price,
                      imageUrl: imageUrl,
                      createdAt: DateTime.now(),
                      isFavorite: false,
                      userId: 0,
                      username: null,
                    );

                    await ProductService.addProduct(product);

                    Navigator.pop(context);
                    _refreshProducts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product added successfully!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding product: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Antika Marketplace"),
        actions: [
          // Backend connection indicator
          IconButton(
            icon: Icon(
              _backendConnected ? Icons.wifi : Icons.wifi_off,
              color: _backendConnected ? Colors.green : Colors.red,
            ),
            onPressed: _checkBackendConnection,
            tooltip: _backendConnected
                ? 'Connected to backend'
                : 'Backend disconnected',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterModal,
            tooltip: "Filter products",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          // Backend status banner
          if (!_backendConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Using local data. Some features may be limited.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    onPressed: _checkBackendConnection,
                    tooltip: 'Retry connection',
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    _filterProducts();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          "Error loading products",
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshProducts,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data ?? [];
                _filteredProducts = products;

                if (_filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No products found",
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showFavoritesOnly
                              ? "You don't have any favorite products"
                              : "Add your first product!",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshProducts,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text("Add Product"),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: product.imageUrl!.startsWith('http')
                              ? Image.network(
                                  product.imageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                )
                              : Image.file(
                                  File(product.imageUrl!),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "\$${product.price.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              product.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: product.isFavorite ? Colors.red : null,
                              size: 20,
                            ),
                            onPressed: () async {
                              await ProductService.toggleFavorite(product.id);
                              _refreshProducts();
                            },
                          ),
                        ],
                      ),

                      // AUCTION SECTION
                      if (product.isAuction) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.gavel,
                                    size: 16,
                                    color: Colors.amber[800],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AUCTION',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Bid:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '\$${(product.currentBid ?? product.price).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AuctionDetailScreen(
                                                productId: product.id,
                                              ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text(
                                      'Bid Now',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  product.createdAt.day.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (product.username != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.username!,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
