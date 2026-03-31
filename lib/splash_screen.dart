import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;
  late AnimationController _logoJumpController;
  late Animation<double> _logoJumpAnimation;
  late AnimationController _textController;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));

    _logoJumpController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _logoJumpAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -80),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -80, end: 0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _logoJumpController,
      curve: Curves.easeInOut,
    ));

    _textController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _textAnimation = Tween<double>(
      begin: 80,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _runAnimations();
  }

  void _runAnimations() async {
    await _rotateController.forward();
    _logoJumpController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    await _textController.forward();
    await Future.delayed(Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _logoJumpController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF071739),
      body: Stack(
        children: [

          Positioned(
  top: -80,
  right: -80,
  child: Container(
    width: 250,
    height: 250,
    decoration: BoxDecoration(
      color: Color(0xFF5B7FA6),
      shape: BoxShape.circle,
    ),
  ),
),

// فوق يمين — البيج فوق
Positioned(
  top: -60,
  right: -60,
  child: Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      color: Color(0xFFE3C39D),
      shape: BoxShape.circle,
    ),
  ),
),

         
Positioned(
  bottom: -80,
  left: -80,
  child: Container(
    width: 250,
    height: 250,
    decoration: BoxDecoration(
      color: Color(0xFF5B7FA6),
      shape: BoxShape.circle,
    ),
  ),
),

// تحت يسار — البيج فوق
Positioned(
  bottom: -60,
  left: -60,
  child: Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      color: Color(0xFFE3C39D),
      shape: BoxShape.circle,
    ),
  ),
),
          // المحتوى الأصلي
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _rotateAnimation,
                    _logoJumpAnimation,
                  ]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _logoJumpAnimation.value),
                      child: RotationTransition(
                        turns: _rotateAnimation,
                        child: Image.asset(
                          'images/enginet_logo.png',
                          width: 130,
                          height: 130,
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 20),

                AnimatedBuilder(
                  animation: _textAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _textAnimation.value),
                      child: Opacity(
                        opacity: 1 - (_textAnimation.value / 80),
                        child: Text(
                          "EngiNet",
                          style: GoogleFonts.agbalumo(
                            fontSize: 40,
                            color: Color(0xFFE3C39D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}