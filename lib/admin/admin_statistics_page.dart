import 'package:flutter/material.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';

class AdminStatisticsPage extends StatefulWidget {
  @override
  _AdminStatisticsPageState createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final function = ParseCloudFunction('getAdminStatistics');
      final response = await function.execute(parameters: {});
      
      if (response.success && response.result != null) {
        setState(() {
          _stats = Map<String, dynamic>.from(response.result as Map);
          _isLoading = false;
        });
      } else {
        throw Exception(response.error?.message ?? 'Неизвестная ошибка');
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Статистика'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStatistics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: Colors.red)),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadStatistics,
                          child: Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final users = _stats['users'] as Map<String, dynamic>? ?? {};
    final lessons = _stats['lessons'] as Map<String, dynamic>? ?? {};
    final cars = _stats['cars'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Пользователи', Icons.people),
          SizedBox(height: 8),
          _buildInfoRow('Всего', '${users['total'] ?? 0}', Icons.supervisor_account),
          _buildInfoRow('Админы', '${users['admins'] ?? 0}', Icons.admin_panel_settings, Colors.purple),
          _buildInfoRow('Инструкторы', '${users['instructors'] ?? 0}', Icons.person, Colors.blue),
          _buildInfoRow('Студенты', '${users['students'] ?? 0}', Icons.school, Colors.green),
          SizedBox(height: 16),
          
          _buildSectionTitle('Занятия', Icons.book),
          SizedBox(height: 8),
          _buildInfoRow('Запланировано', '${lessons['scheduled'] ?? 0}', Icons.event, Colors.orange),
          _buildInfoRow('Идут сейчас', '${lessons['active'] ?? 0}', Icons.play_circle, Colors.green),
          _buildInfoRow('Завершено', '${lessons['completed'] ?? 0}', Icons.check_circle, Colors.blue),
          _buildInfoRow('Отменено', '${lessons['cancelled'] ?? 0}', Icons.cancel, Colors.red),
          _buildInfoRow('Сегодня', '${lessons['today'] ?? 0}', Icons.today, Colors.blueAccent),
          SizedBox(height: 16),
          
          _buildSectionTitle('Автомобили', Icons.directions_car),
          SizedBox(height: 8),
          _buildInfoRow('Всего', '${cars['total'] ?? 0}', Icons.directions_car),
          _buildInfoRow('Активные', '${cars['active'] ?? 0}', Icons.check_circle, Colors.green),
          _buildInfoRow('Неактивные', '${cars['inactive'] ?? 0}', Icons.cancel, Colors.grey),
          SizedBox(height: 16),
          
          _buildSectionTitle('Активность', Icons.trending_up),
          SizedBox(height: 8),
          _buildInfoRow('Новых за неделю', '${users['newWeek'] ?? 0}', Icons.calendar_today, Colors.blue),
          _buildInfoRow('Новых за месяц', '${users['newMonth'] ?? 0}', Icons.calendar_month, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 16)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
