import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class BenchmarkPriceItem {
  final String title;
  final String category;
  final double averagePrice;
  final IconData icon;

  const BenchmarkPriceItem({
    required this.title,
    required this.category,
    required this.averagePrice,
    required this.icon,
  });
}

class BenchmarkPriceCardList extends StatelessWidget {
  final Function(BenchmarkPriceItem item) onSelectPriceItem;

  const BenchmarkPriceCardList({
    super.key,
    required this.onSelectPriceItem,
  });

  static const List<BenchmarkPriceItem> items = [
    BenchmarkPriceItem(
      title: 'Destapar cañería',
      category: 'Plomería',
      averagePrice: 40000.0,
      icon: Icons.plumbing_rounded,
    ),
    BenchmarkPriceItem(
      title: 'Reparar canilla',
      category: 'Plomería',
      averagePrice: 28000.0,
      icon: Icons.water_drop_rounded,
    ),
    BenchmarkPriceItem(
      title: 'Cambio de térmica',
      category: 'Electricidad',
      averagePrice: 32000.0,
      icon: Icons.bolt_rounded,
    ),
    BenchmarkPriceItem(
      title: 'Instalación de estufa',
      category: 'Gas',
      averagePrice: 45000.0,
      icon: Icons.local_fire_department_rounded,
    ),
    BenchmarkPriceItem(
      title: 'Pintura de ambiente',
      category: 'Pintura',
      averagePrice: 75000.0,
      icon: Icons.format_paint_rounded,
    ),
    BenchmarkPriceItem(
      title: 'Flete urbano',
      category: 'Flete',
      averagePrice: 38000.0,
      icon: Icons.local_shipping_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Precios Promedio de Referencia',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Transparencia Reparatutti',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => onSelectPriceItem(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2412) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.accentYellow : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '~\$${item.averagePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.accentYellow : AppColors.mustardLight,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ARS',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
