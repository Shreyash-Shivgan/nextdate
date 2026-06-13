import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Phone Auth Controllers
  final _phoneController = TextEditingController(text: "+91");
  final _otpController = TextEditingController();

  // Tab state: 0 = Email/Social, 1 = Phone
  int _activeTab = 0;
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Phone Auth state
  bool _otpSent = false;
  String _verificationId = "";
  int? _resendToken;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Email Sign In / Sign Up
  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred. Please check your credentials.";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = "Invalid email or password.";
      } else if (e.code == 'email-already-in-use') {
        message = "The email address is already in use by another account.";
      } else if (e.code == 'invalid-email') {
        message = "The email address is badly formatted.";
      } else if (e.code == 'weak-password') {
        message = "The password is too weak.";
      } else if (e.message != null) {
        message = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User cancelled the sign-in flow
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Sign-In failed: ${e.toString()}"),
            backgroundColor: AppTheme.coralAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Send Phone OTP
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid phone number (with country code, e.g. +91...)"),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (mainly on Android)
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String errMsg = e.message ?? "Phone verification failed.";
          if (e.code == 'invalid-phone-number') {
            errMsg = "The provided phone number is not valid.";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: AppTheme.coralAccent,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Verification code sent! 💬"),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Verify Phone OTP
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the 6-digit verification code"),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Invalid OTP code. Please try again."),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: AppTheme.coralAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.coralAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 60,
                      color: AppTheme.coralAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // App Title
                Text(
                  "NextDate",
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.primaryNavy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                
                // App Subtitle
                Text(
                  "Your next date, figured out.",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.softGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Custom Tab Segmented Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff162536) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Tab 1: Email / Social
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeTab = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 0
                                  ? AppTheme.coralAccent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "Email & Google",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 0
                                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                      : AppTheme.softGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tab 2: Phone Number
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeTab = 1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _activeTab == 1
                                  ? AppTheme.coralAccent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "Phone Auth",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 1
                                      ? (isDark ? AppTheme.primaryNavy : Colors.white)
                                      : AppTheme.softGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Tab Content
                _activeTab == 0 ? _buildEmailSocialTab(isDark) : _buildPhoneTab(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // EMAIL & GOOGLE TAB
  Widget _buildEmailSocialTab(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          Text(
            "Email Address",
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.coralAccent,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
            decoration: InputDecoration(
              hintText: "example@domain.com",
              hintStyle: const TextStyle(color: AppTheme.softGrey),
              prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.softGrey),
              filled: true,
              fillColor: isDark ? const Color(0xff162536) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Email is required";
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                return "Enter a valid email address";
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          
          // Password
          Text(
            "Password",
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.coralAccent,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
            decoration: InputDecoration(
              hintText: "••••••••",
              hintStyle: const TextStyle(color: AppTheme.softGrey),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.softGrey),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.softGrey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: isDark ? const Color(0xff162536) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return "Password is required";
              }
              if (val.length < 6) {
                return "Password must be at least 6 characters";
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          
          // Confirm Password
          if (!_isLogin) ...[
            Text(
              "Confirm Password",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.coralAccent,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
              decoration: InputDecoration(
                hintText: "••••••••",
                hintStyle: const TextStyle(color: AppTheme.softGrey),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.softGrey),
                filled: true,
                fillColor: isDark ? const Color(0xff162536) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
                ),
              ),
              validator: (val) {
                if (!_isLogin) {
                  if (val == null || val.isEmpty) {
                    return "Please confirm your password";
                  }
                  if (val != _passwordController.text) {
                    return "Passwords do not match";
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],
          
          const SizedBox(height: 12),
          
          // Email Action Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitEmailAuth,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isLogin ? "Sign In with Email" : "Create Account",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Toggle Login / Signup
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
            child: Text(
              _isLogin
                  ? "Don't have an account? Sign Up"
                  : "Already have an account? Sign In",
              style: GoogleFonts.inter(
                color: AppTheme.coralAccent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppTheme.softGrey.withOpacity(0.4),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "or",
                  style: GoogleFonts.inter(
                    color: AppTheme.softGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppTheme.softGrey.withOpacity(0.4),
                  thickness: 1,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Google Sign In Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: isDark ? AppTheme.softGrey.withOpacity(0.4) : Colors.grey.shade300,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: isDark ? const Color(0xff162536) : Colors.white,
            ),
            onPressed: _isLoading ? null : _signInWithGoogle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google Icon Asset
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.account_circle_outlined,
                    color: AppTheme.coralAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Continue with Google",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHONE NUMBER TAB
  Widget _buildPhoneTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_otpSent) ...[
          // Phone Input Phase
          Text(
            "Phone Number",
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.coralAccent,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
            decoration: InputDecoration(
              hintText: "+91 9876543210",
              hintStyle: const TextStyle(color: AppTheme.softGrey),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.softGrey),
              filled: true,
              fillColor: isDark ? const Color(0xff162536) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Send Verification Code",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We will send a 6-digit verification code to this number.",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.softGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          // OTP Verification Phase
          Text(
            "Enter Verification Code",
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.coralAccent,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryNavy),
            maxLength: 6,
            decoration: InputDecoration(
              hintText: "123456",
              hintStyle: const TextStyle(color: AppTheme.softGrey),
              prefixIcon: const Icon(Icons.lock_open_rounded, color: AppTheme.softGrey),
              filled: true,
              fillColor: isDark ? const Color(0xff162536) : Colors.white,
              counterText: "",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softGrey.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.coralAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Verify & Sign In",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  });
                },
                child: Text(
                  "Change Number",
                  style: GoogleFonts.inter(
                    color: AppTheme.softGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: Text(
                  "Resend Code",
                  style: GoogleFonts.inter(
                    color: AppTheme.coralAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }
}
