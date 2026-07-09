import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // กำหนดสี Primary
    const Color primaryColor = Color(0xFF0F2557); 

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, "Home", 0, primaryColor),
          _buildNavItem(Icons.history_rounded, "History", 1, primaryColor),          
          _buildNavItem(Icons.notifications_rounded, "Notification", 2, primaryColor),  
          _buildNavItem(Icons.devices_rounded, "Device", 3, primaryColor),
          _buildNavItem(Icons.report_rounded, "Report", 4, primaryColor),        
          _buildNavItem(Icons.person_rounded, "Profile", 5, primaryColor),        
        ],
      ),
    );
  }

  // Widget สร้างปุ่มเมนูย่อย
  Widget _buildNavItem(IconData icon, String label, int index, Color activeColor) {
    final bool isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 80,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isActive ? activeColor : Colors.grey.shade400,
              ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? activeColor : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}