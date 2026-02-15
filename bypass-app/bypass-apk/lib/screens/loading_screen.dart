import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LoadingScreen extends StatelessWidget {
  final String message;
  final bool hasError;
  final String? errorMessage;
  
  const LoadingScreen({
    super.key,
    this.message = 'Загрузка...',
    this.hasError = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!hasError) ...[
              CircularProgressIndicator(
                color: AppConstants.phase3Color,
              ),
              const SizedBox(height: 30),
              Text(
                message,
                style: TextStyle(
                  color: AppConstants.textPrimaryColor,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ] else ...[
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppConstants.phase3Color,
              ),
              const SizedBox(height: 20),
              Text(
                'Ошибка загрузки',
                style: TextStyle(
                  color: AppConstants.phase3Color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  errorMessage ?? 'Неизвестная ошибка',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Перезапуск приложения
                  Navigator.of(context).pushReplacementNamed('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.phase3Color,
                ),
                child: const Text('ПОВТОРИТЬ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
