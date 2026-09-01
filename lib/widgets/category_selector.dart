import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  final List<String> categories = const ['All', 'Afrobeats', 'Nollywood', 'Tech', 'Politics'];
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;

          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.14),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat == 'All' ? 'All News' : cat,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white.withOpacity(0.85),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
