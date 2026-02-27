import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';


// ==================== GLOBAL USER SESSION ====================

class UserSession {
  static final UserSession _instance = UserSession._internal();
  
  factory UserSession() {
    return _instance;
  }
  UserSession._internal();


  String? _role;
  String? _department; // For supervisors: 'Sewing', 'Cutting', 'Finishing'
  int _selectedUnit = -1; // For Sewing supervisors: which unit they're assigned to (-1 = all/none)
  
  String? get role => _role;
  String? get department => _department;
  int get selectedUnit => _selectedUnit;
  
  void setUserSession(String role, {String? department, int selectedUnit = -1}) {
    _role = role;
    _department = department;
    _selectedUnit = selectedUnit;
  }
  
  void clearSession() {
    _role = null;
    _department = null;
    _selectedUnit = -1;
  }
  
  bool isSupervisorWithDepartment(String dept) {
    return _role == 'supervisor' && _department == dept;
  }
}

// ==================== GLOBAL ORDER MANAGER ====================

class OrderLineData {
  String buyerName;
  String style;
  String item;
  String color;
  int target;
  String operator;
  String shortOperator;
  String bartechOperator;
  String bartechHelper;
  int unitNumber;
  int lineNumber;

  // Fields that supervisor will fill
  int dailyCutting;
  int dailyInput;
  String supervisorNotes;
  // Finishing targets (if applicable)
  int qcTarget;
  int polyTarget;
  int ironTarget;
  
  // Department info
  String department; // 'Cutting', 'Sewing', 'Finishing'
  int achieve; // For Sewing

  OrderLineData({
    required this.buyerName,
    required this.style,
    required this.item,
    required this.color,
    required this.target,
    required this.operator,
    required this.shortOperator,
    required this.bartechOperator,
    required this.bartechHelper,
    this.unitNumber = 0,
    this.lineNumber = 0,
    this.dailyCutting = 0,
    this.dailyInput = 0,
    this.supervisorNotes = '',
    this.department = 'Cutting',
    this.achieve = 0,
    this.qcTarget = 0,
    this.polyTarget = 0,
    this.ironTarget = 0,
  });
}

class Order {
  String orderName;
  List<OrderLineData> lines = [];
  DateTime createdDate;
  bool submittedBySupervisor;

  Order({
    required this.orderName,
    List<OrderLineData>? lines,
  })  : createdDate = DateTime.now(),
        submittedBySupervisor = false,
        lines = lines ?? [];
}

class OrderManager {
  static final OrderManager _instance = OrderManager._internal();

  factory OrderManager() {
    return _instance;
  }

  OrderManager._internal();

  final List<Order> _orders = [];

  void addOrder(Order order) {
    _orders.add(order);
  }

  List<Order> getAllOrders() {
    return _orders;
  }

  Order? getOrder(int index) {
    if (index >= 0 && index < _orders.length) {
      return _orders[index];
    }
    return null;
  }

  void updateOrderLine(int orderIndex, int lineIndex, OrderLineData updatedLine) {
    if (orderIndex >= 0 && orderIndex < _orders.length) {
      if (lineIndex >= 0 && lineIndex < _orders[orderIndex].lines.length) {
        _orders[orderIndex].lines[lineIndex] = updatedLine;
        _orders[orderIndex].submittedBySupervisor = true;
      }
    }
  }

  // Get orders filtered by supervisor's department
  List<Order> getOrdersByDepartment(String department) {
    final filteredOrders = <Order>[];
    for (var order in _orders) {
      final filteredLines = order.lines
          .where((line) => line.department == department)
          .toList();
      if (filteredLines.isNotEmpty) {
        final filteredOrder = Order(
          orderName: order.orderName,
          lines: filteredLines,
        );
        filteredOrders.add(filteredOrder);
      }
    }
    return filteredOrders;
  }

  void notifyListeners() {
    // This will be called to update UI
  }
}

final orderManager = OrderManager();

// Global data storage for Admin's Purchase Orders and Reports
late List<PurchaseOrder> globalPurchaseOrders;
late List<ProductionReport> globalProductionReports;

void initializeGlobalData() {
  globalPurchaseOrders = [];
  globalProductionReports = [];
}

// Default sample data is defined inline inside `_initializeSampleData()`.

void main() {
  initializeGlobalData();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ' KTL Production Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        '/admin': (context) => const ProductionTrackerApp(),
        '/supervisor': (context) => const SupervisorInputScreen(),
      },
    );
  }
}
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'admin'; // Default role
  String? _selectedDepartment; // For supervisors
  int? _selectedUnit; // For Sewing supervisors
  bool _isLoading = false;

  final List<String> _roles = ['admin', 'supervisor'];
  final List<String> _departments = ['Cutting', 'Sewing', 'Finishing'];
  final List<int> _units = [1, 2];

  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Email and Password')),
      );
      return;
    }

    // If supervisor, department is required
    if (_selectedRole == 'supervisor' && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Department')),
      );
      return;
    }

    // If Sewing supervisor, unit is required
    if (_selectedRole == 'supervisor' && _selectedDepartment == 'Sewing' && _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Unit')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate login delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });

      // Set user session
      UserSession().setUserSession(
        _selectedRole,
        department: _selectedDepartment,
        selectedUnit: _selectedUnit ?? -1,
      );

      // Navigate based on role
      if (_selectedRole == 'admin') {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else if (_selectedRole == 'supervisor') {
        Navigator.of(context).pushReplacementNamed('/supervisor');
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white10, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Center(
                      child: Icon(Icons.factory, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'KTL Production',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
               
                  Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 20),
            
                  // Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      //labelText: 'Email Address',
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
            
                  // Password with toggle
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      //labelText: 'Password',
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      labelStyle: const TextStyle(color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.blue.shade600),
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Role
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Select Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
                      filled: true,
                      fillColor: Colors.blue.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.blue.shade600),
                    ),
                    items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role == 'admin' ? 'Admin' : 'Supervisor'))).toList(),
                    onChanged: (v) => setState(() { _selectedRole = v ?? 'admin'; _selectedDepartment = null; _selectedUnit = null; }),
                  ),
                  const SizedBox(height: 12),
                  // Department (only for Supervisor)
                  if (_selectedRole == 'supervisor')
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: InputDecoration(
                        labelText: 'Select Department *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.amber.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.amber.shade300, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.amber.shade600, width: 2)),
                        filled: true,
                        fillColor: Colors.amber.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: Icon(Icons.work_outline, color: Colors.amber.shade700),
                      ),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) => setState(() { _selectedDepartment = v; _selectedUnit = null; }),
                    ),
            
                  // Unit (only for Sewing Supervisor)
                  if (_selectedRole == 'supervisor' && _selectedDepartment == 'Sewing')
                    const SizedBox(height: 12),
                  if (_selectedRole == 'supervisor' && _selectedDepartment == 'Sewing')
                    DropdownButtonFormField<int>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Select Unit *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green.shade300, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
                        filled: true,
                        fillColor: Colors.green.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: Icon(Icons.pin_outlined, color: Colors.green.shade700),
                      ),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text('Unit $u'))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v),
                    ),
            
                  const SizedBox(height: 20),
            
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        shadowColor: Colors.blue.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
            
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Need access? ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('Contact Admin', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// ==================== DATA MODELS ====================

class LineData {
  int lineNumber;
  int unitNumber;
  String buyerName; // Buyer Name / Factory
  String style;
  String item;
  String color; // For Cutting section
  //String team; // For Cutting section
  int target;
  int achieve; // Daily Cutting
  int dailyInput; // Daily Input (separate from achieve)
  int balance;
  int totalInput; // Total cumulative input
  String operator;
  String shortOperator;
  String helper;
  String shortHelper;
  String bartechOperator; // Bartech operator
  String bartechHelper; // Bartech helper
  String notes;
  String department; // Department: 'Cutting', 'Sewing', or 'Finishing'

  LineData({
    required this.lineNumber,
    required this.unitNumber,
    required this.target,
    this.buyerName = '',
    this.style = '',
    this.item = '',
    this.color = '',
    //this.team = '',
    this.achieve = 0,
    this.dailyInput = 0,
    this.balance = 0,
    this.totalInput = 0,
    this.operator = '',
    this.shortOperator = '',
    this.helper = '',
    this.shortHelper = '',
    this.bartechOperator = '',
    this.bartechHelper = '',
    this.notes = '',
    this.department = '',
  });
}

class HourlyUpdate {
  int hour;
  List<LineData> lines = [];
  String notes;
  String date; // Date when this hourly update was created
  // Finishing sections
  int qcTarget = 0;
  int qcAchieve = 0;
  int polyTarget = 0;
  int polyAchieve = 0;
  int ironTarget = 0;
  int ironAchieve = 0;
  
  // New finishing fields
  List<String> buyerNames = []; // Buyer names (multiple choice)
  int totalFinishingManpower = 0; // Total finishing man power
  String finishingOperator = ''; // Finishing operator name
  String style = ''; // Style name for finishing
  String color = ''; // Color for finishing
  String item = ''; // Item type for finishing

  HourlyUpdate({
    required this.hour, 
    this.notes = '',
    String? date,
  }) : date = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  int getTotalInput() {
    // For Cutting/Sewing: sum from lines
    int lineTotal = lines.fold(0, (sum, line) => sum + line.achieve);
    // For Finishing: sum from QC, Poly, Iron achieve values
    int finishingTotal = qcAchieve + polyAchieve + ironAchieve;
    return lineTotal + finishingTotal;
  }

  int getTotalBalance() {
    // For Cutting/Sewing: sum from lines
    int lineTotal = lines.fold(0, (sum, line) => sum + line.balance);
    // For Finishing: sum from QC, Poly, Iron targets minus achieves
    int finishingBalance = (qcTarget - qcAchieve) + (polyTarget - polyAchieve) + (ironTarget - ironAchieve);
    return lineTotal + finishingBalance;
  }
}

class StyleItem {
  final String styleId;
  final String styleCode;
  final String color;
  final String itemType; // Long Pant, Short Pant, etc
  int totalQuantity;
  String buyerName; // Buyer name for this style

  // Department-wise hourly updates
  Map<String, List<HourlyUpdate>> departmentHourlyUpdates = {
    'Cutting': [],
    'Sewing': [],
    'Finishing': [],
  };

  StyleItem({
    required this.styleId,
    required this.styleCode,
    required this.color,
    required this.itemType,
    this.totalQuantity = 0,
    this.buyerName = '',
  });
}

class PurchaseOrder {
  final String poNumber;
  final String factory;
  List<StyleItem> styles = [];

  PurchaseOrder({required this.poNumber, required this.factory});
}

class ProductionReport {
  String reportId;
  String poNumber;
  String styleId;
  String styleName; // Style name/code
  String color; // Color
  String itemType; // Item type
  String department; // Cutting, Sewing, Finishing
  String date;
  int totalInput = 0;
  int totalBalance = 0;
  int totalProduced = 0;
  int totalQcPass = 0;
  Map<int, HourlyUpdate> hourlyData = {}; // Hour -> Update

  ProductionReport({
    required this.reportId,
    required this.poNumber,
    required this.styleId,
    required this.styleName,
    required this.color,
    required this.itemType,
    required this.department,
    required this.date,
  });

  int getDailyTotal({int selectedUnit = -1}) {
    if (selectedUnit <= 0) {
      // No unit filter, sum all
      return hourlyData.values.fold(0, (sum, h) => sum + h.getTotalInput());
    }
    // Filter by unit only (for Sewing department)
    return hourlyData.values.fold(0, (sum, h) {
      final unitLines = h.lines.where((line) => line.unitNumber == selectedUnit).toList();
      int lineTotal = unitLines.fold(0, (s, line) => s + line.achieve);
      return sum + lineTotal;
    });
  }
}

// ==================== FINISHING DIALOG WIDGET ====================

class FinishingHourlyDialog extends StatefulWidget {
  final HourlyUpdate update;
  final VoidCallback onSave;
  
  const FinishingHourlyDialog({
    required this.update,
    required this.onSave,
    super.key,
  });

  @override
  State<FinishingHourlyDialog> createState() => _FinishingHourlyDialogState();
}

class _FinishingHourlyDialogState extends State<FinishingHourlyDialog> {
  late TextEditingController qcTargetController;
  late TextEditingController qcAchieveController;
  late TextEditingController polyTargetController;
  late TextEditingController polyAchieveController;
  late TextEditingController ironTargetController;
  late TextEditingController ironAchieveController;
  late TextEditingController manpowerController;
  late TextEditingController operatorController;
  late TextEditingController styleController;
  late TextEditingController colorController;
  late TextEditingController itemController;

  final buyerOptions = ['Winner Jeans', 'Dreamtex', 'Fashion Fast'];

  @override
  void initState() {
    super.initState();
    qcTargetController = TextEditingController(text: widget.update.qcTarget.toString());
    qcAchieveController = TextEditingController(text: widget.update.qcAchieve.toString());
    polyTargetController = TextEditingController(text: widget.update.polyTarget.toString());
    polyAchieveController = TextEditingController(text: widget.update.polyAchieve.toString());
    ironTargetController = TextEditingController(text: widget.update.ironTarget.toString());
    ironAchieveController = TextEditingController(text: widget.update.ironAchieve.toString());
    manpowerController = TextEditingController(text: widget.update.totalFinishingManpower.toString());
    operatorController = TextEditingController(text: widget.update.finishingOperator);
    styleController = TextEditingController(text: widget.update.style);
    colorController = TextEditingController(text: widget.update.color);
    itemController = TextEditingController(text: widget.update.item);
  }

  @override
  void dispose() {
    qcTargetController.dispose();
    qcAchieveController.dispose();
    polyTargetController.dispose();
    polyAchieveController.dispose();
    ironTargetController.dispose();
    ironAchieveController.dispose();
    manpowerController.dispose();
    operatorController.dispose();
    styleController.dispose();
    colorController.dispose();
    itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus();
        return true;
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hour ${widget.update.hour == 11 ? 'Overtime' : widget.update.hour}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                // Buyer Name (Multiple Choice with Checkboxes)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buyer Name (Select 2-3)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: buyerOptions.map((buyer) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: widget.update.buyerNames.contains(buyer),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  widget.update.buyerNames.add(buyer);
                                } else {
                                  widget.update.buyerNames.remove(buyer);
                                }
                              });
                            },
                            title: Text(
                              buyer,
                              style: const TextStyle(fontSize: 12),
                            ),
                            activeColor: Colors.blue,
                          );
                        }).toList(),
                      ),
                      Text(
                        'Selected: ${widget.update.buyerNames.isNotEmpty ? widget.update.buyerNames.join(", ") : "None"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // QC Input
                _buildQCField(),
                const SizedBox(height: 16),
                // Poly Input
                _buildPolyField(),
                const SizedBox(height: 16),
                // Iron Input
                _buildIronField(),
                const SizedBox(height: 16),
                // Style, Color, Item (Finishing specific)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Style, Color, Item',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: styleController,
                        decoration: InputDecoration(
                          labelText: 'Style',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (val) {
                          widget.update.style = val;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: colorController,
                        decoration: InputDecoration(
                          labelText: 'Color',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (val) {
                          widget.update.color = val;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: itemController,
                        decoration: InputDecoration(
                          labelText: 'Item',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (val) {
                          widget.update.item = val;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Total Finishing Manpower
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Finishing Manpower',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Number of Workers',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        controller: manpowerController,
                        onChanged: (val) {
                          widget.update.totalFinishingManpower = int.tryParse(val) ?? 0;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Finishing Operator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Finishing Operator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Operator',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                        controller: operatorController,
                        onChanged: (val) {
                          widget.update.finishingOperator = val;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Fixed buttons at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildQCField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✓ QC',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qcTargetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Total Target',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.qcTarget = int.tryParse(val) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: qcAchieveController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Achieve',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.qcAchieve = int.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolyField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📦 Poly',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: polyTargetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Total Target',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.polyTarget = int.tryParse(val) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: polyAchieveController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Achieve',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.polyAchieve = int.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIronField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔩 Iron',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ironTargetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Total Target',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.ironTarget = int.tryParse(val) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ironAchieveController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Achieve',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    widget.update.ironAchieve = int.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== SUPERVISOR INPUT SCREEN ====================

class SupervisorInputScreen extends StatefulWidget {
  const SupervisorInputScreen({super.key});

  @override
  State<SupervisorInputScreen> createState() => _SupervisorInputScreenState();
}

class _SupervisorInputScreenState extends State<SupervisorInputScreen> {
  String? expandedCardKey; // format: "orderIndex_lineIndex"
  
  // Store persistent TextEditingControllers per line
  final Map<String, TextEditingController> cuttingControllers = {};
  final Map<String, TextEditingController> achieveControllers = {};
  final Map<String, TextEditingController> qcControllers = {};
  final Map<String, TextEditingController> polyControllers = {};
  final Map<String, TextEditingController> ironControllers = {};
  
  // Store last saved values per line to display after save
  final Map<String, Map<String, String>> savedValues = {};

  @override
  void dispose() {
    // Dispose all controllers
    cuttingControllers.values.forEach((controller) => controller.dispose());
    achieveControllers.values.forEach((controller) => controller.dispose());
    qcControllers.values.forEach((controller) => controller.dispose());
    polyControllers.values.forEach((controller) => controller.dispose());
    ironControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _syncToAdminData(OrderLineData updatedLine, int lineIndex) {
    // Update the global purchase orders with supervisor's data
    // CRITICAL: Only sync to the matching department's hourly updates
    try {
      final String supervisorDept = updatedLine.department.trim();
      if (supervisorDept.isEmpty) {
        print('Warning: supervisor line has no department set');
        return;
      }
      // UNIT VALIDATION: Sewing supervisors can only sync their assigned unit
      if (supervisorDept == 'Sewing') {
        final supervisorUnit = UserSession().selectedUnit;
        if (supervisorUnit > 0 && updatedLine.unitNumber > 0 && updatedLine.unitNumber != supervisorUnit) {
          print('Security: Sewing supervisor ${supervisorUnit} tried to sync Unit ${updatedLine.unitNumber} data - BLOCKED');
          return;
        }
      }

      for (var po in globalPurchaseOrders) {
        for (var style in po.styles) {
          // ONLY access the specific department's hourly list
          final deptList = style.departmentHourlyUpdates[supervisorDept] ?? [];
          
          for (var hourly in deptList) {
            bool foundMatch = false;
            
            // FIRST PASS: Try exact unit+line match (HIGHEST PRIORITY)
            if (updatedLine.unitNumber > 0 && updatedLine.lineNumber > 0) {
              for (int i = 0; i < hourly.lines.length; i++) {
                final line = hourly.lines[i];
                
                // Extra safety: ensure line belongs to the same department
                if (line.department.trim() != supervisorDept) {
                  continue;
                }

                // EXACT unit+line match
                if (line.unitNumber == updatedLine.unitNumber && line.lineNumber == updatedLine.lineNumber) {
                  // Map based on department
                  if (supervisorDept == 'Cutting') {
                    line.dailyInput = updatedLine.dailyInput;
                    line.achieve = updatedLine.dailyCutting; // Cutting: use dailyCutting
                  } else if (supervisorDept == 'Sewing') {
                    line.achieve = updatedLine.achieve;       // Sewing: use achieve
                    line.dailyInput = updatedLine.dailyInput;
                  } else if (supervisorDept == 'Finishing') {
                    line.dailyInput = updatedLine.dailyInput;
                    line.achieve = updatedLine.achieve;
                  }
                  line.notes = updatedLine.supervisorNotes;
                  foundMatch = true;
                  break;
                }
              }
            }
            
            // SECOND PASS: Only do fallback matching if exact match didn't work
            if (!foundMatch) {
              for (int i = 0; i < hourly.lines.length; i++) {
                final line = hourly.lines[i];
                
                // Extra safety: ensure line belongs to the same department
                if (line.department.trim() != supervisorDept) {
                  continue;
                }

                // Fallback: match by buyer/style/item/color
                final bool fallbackMatch = (line.buyerName == updatedLine.buyerName &&
                    line.style == updatedLine.style &&
                    (updatedLine.item.isEmpty || line.item == updatedLine.item) &&
                    (updatedLine.color.isEmpty || line.color == updatedLine.color));

                if (fallbackMatch) {
                  // Map based on department
                  if (supervisorDept == 'Cutting') {
                    line.dailyInput = updatedLine.dailyInput;
                    line.achieve = updatedLine.dailyCutting; // Cutting: use dailyCutting
                  } else if (supervisorDept == 'Sewing') {
                    line.achieve = updatedLine.achieve;       // Sewing: use achieve
                    line.dailyInput = updatedLine.dailyInput;
                  } else if (supervisorDept == 'Finishing') {
                    line.dailyInput = updatedLine.dailyInput;
                    line.achieve = updatedLine.achieve;
                  }
                  line.notes = updatedLine.supervisorNotes;
                  foundMatch = true;
                  break;
                }
              }
            }
            
            if (foundMatch) break; // Stop after first hourly match
          }
        }
      }
    } catch (e) {
      print('Sync to admin error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the supervisor's department from UserSession
    final supervisorDepartment = UserSession().department;
    
    // For Finishing department, show PurchaseOrders from globalPurchaseOrders
    if (supervisorDepartment == 'Finishing') {
      return Scaffold(
        appBar: AppBar(
          title: Text('Supervisor - $supervisorDepartment'),
          backgroundColor: Colors.orange,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: _logout,
                child: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
        body: globalPurchaseOrders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox,
                      size: 80,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Purchase Orders Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Wait for Admin to create purchase orders',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: globalPurchaseOrders.length,
                itemBuilder: (context, poIndex) {
                  final po = globalPurchaseOrders[poIndex];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(
                        'PO: ${po.poNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Factory: ${po.factory} - ${po.styles.length} styles',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: List.generate(
                              po.styles.length,
                              (styleIndex) {
                                final style = po.styles[styleIndex];
                                return _buildFinishingStyleCard(context, po, style);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      );
    }

    // For other departments, use orderManager as before
    final List<Order> orders;
    if (supervisorDepartment != null && supervisorDepartment.isNotEmpty) {
      orders = orderManager.getOrdersByDepartment(supervisorDepartment);
    } else {
      orders = orderManager.getAllOrders();
    }

    // Get supervisor's selected unit (for Sewing: should only see their unit)
    final supervisorUnit = UserSession().selectedUnit;

    // Filter orders: for Sewing supervisors, only show lines matching their unit
    final List<Order> filteredOrders = [];
    for (var order in orders) {
      List<OrderLineData> filteredLines = [];
      for (var line in order.lines) {
        // For Sewing: only include lines with matching unit
        if (supervisorDepartment == 'Sewing' && supervisorUnit > 0) {
          if (line.unitNumber == supervisorUnit) {
            filteredLines.add(line);
          }
        } else {
          // For Cutting/Finishing: show all lines
          filteredLines.add(line);
        }
      }
      // Only add order if it has lines for this supervisor
      if (filteredLines.isNotEmpty) {
        final filteredOrder = Order(orderName: order.orderName, lines: filteredLines);
        filteredOrder.submittedBySupervisor = order.submittedBySupervisor;
        filteredOrders.add(filteredOrder);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Supervisor - $supervisorDepartment${supervisorUnit > 0 ? ' (Unit $supervisorUnit)' : ''}'),
        backgroundColor: Colors.orange,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: GestureDetector(
              onTap: _logout,
              child: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: filteredOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Orders Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Wait for Admin to create orders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredOrders.length,
              itemBuilder: (context, filteredIndex) {
                final order = filteredOrders[filteredIndex];
                // Get actual order index from global manager to get correct hour number
                final actualOrderIndex = orderManager.getAllOrders().indexOf(order);
                final hourNumber = (actualOrderIndex + 1).toString().padLeft(2, '0');
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Admin Hour $hourNumber - $supervisorDepartment',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[300]),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: List.generate(
                            order.lines.length,
                            (lineIndex) {
                              final line = order.lines[lineIndex];
                              return _buildLineCard(
                                context,
                                order,
                                line,
                                lineIndex,
                                actualOrderIndex,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFinishingStyleCard(BuildContext context, PurchaseOrder po, StyleItem style) {
    return SizedBox(
  width: double.infinity,
  child: Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Colors.orange.shade50,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style: ${style.styleCode}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text('Color: ${style.color}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('Item: ${style.itemType}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('Buyer: ${style.buyerName}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              _showFinishingHourlyInputDialog(context, po, style);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 122, vertical: 8),
              backgroundColor: Colors.orange,
            ),
            child: const Text('Enter Hourly Data'),
          ),
        ],
      ),
    ),
  ),
);

  }

  void _showFinishingHourlyInputDialog(BuildContext context, PurchaseOrder po, StyleItem style) {
    final allHourlyUpdates = style.departmentHourlyUpdates['Finishing'] ?? [];
    // Filter: only show hours that have targets set by admin
    final hourlyUpdates = allHourlyUpdates.where((h) => h.qcTarget > 0 || h.polyTarget > 0 || h.ironTarget > 0).toList();
    
    if (hourlyUpdates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hourly targets set by admin yet')),
      );
      return;
    }
    
    int currentHourIndex = 0;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final currentHourly = hourlyUpdates[currentHourIndex];
              
              return SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    // Header with progress
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hourly Data - ${style.styleCode}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (currentHourIndex + 1) / hourlyUpdates.length,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hour ${currentHourIndex + 1} of ${hourlyUpdates.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Single hour card (centered)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: _buildSupervisorFinishingHourCard(
                            currentHourly,
                            currentHourIndex,
                            () => setDialogState(() {}),
                          ),
                        ),
                      ),
                    ),
                    // Navigation buttons
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: currentHourIndex > 0
                                    ? () => setDialogState(() => currentHourIndex--)
                                    : null,
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('Previous'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: currentHourIndex < hourlyUpdates.length - 1
                                    ? () => setDialogState(() => currentHourIndex++)
                                    : null,
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: const Text('Next'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {});
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Finish & Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSupervisorFinishingHourCard(HourlyUpdate hourly, int hourIndex, VoidCallback onUpdate) {
    final qcController = TextEditingController(text: hourly.qcAchieve.toString());
    final polyController = TextEditingController(text: hourly.polyAchieve.toString());
    final ironController = TextEditingController(text: hourly.ironAchieve.toString());

    return SizedBox(
      width: 350,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hourly.hour == 11 ? 'Overtime' : 'Hour ${hourly.hour}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              // Show targets from admin
              if (hourly.qcTarget > 0 || hourly.polyTarget > 0 || hourly.ironTarget > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target (from Admin):',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('✓ QC: ${hourly.qcTarget}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('📦 Poly: ${hourly.polyTarget}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('🔩 Iron: ${hourly.ironTarget}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              const Text(
                'Enter Achievements:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qcController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'QC Achieve',
                  hintText: 'Enter achieved qty',
                  prefixIcon: const Icon(Icons.check_circle, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (val) {
                  hourly.qcAchieve = int.tryParse(val) ?? 0;
                  onUpdate();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: polyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Poly Achieve',
                  hintText: 'Enter achieved qty',
                  prefixIcon: const Icon(Icons.check_circle, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (val) {
                  hourly.polyAchieve = int.tryParse(val) ?? 0;
                  onUpdate();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ironController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Iron Achieve',
                  hintText: 'Enter achieved qty',
                  prefixIcon: const Icon(Icons.check_circle, color: Colors.purple),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (val) {
                  hourly.ironAchieve = int.tryParse(val) ?? 0;
                  onUpdate();
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Achieved:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${hourly.qcAchieve + hourly.polyAchieve + hourly.ironAchieve}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(
    BuildContext context,
    Order order,
    OrderLineData line,
    int lineIndex,
    int orderIndex,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Line Number, Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Line ${lineIndex + 1} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${line.color} | ${line.buyerName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (line.dailyCutting > 0 || line.dailyInput > 0 || line.achieve > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Filled',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Form section - always visible
            const Divider(),
            _buildInlineForm(context, order, line, lineIndex, orderIndex),
          ],
        ),
      ),
    );
  }

  // Sync finishing QC/Poly/Iron back into admin HourlyUpdates
  void _syncFinishingToAdmin(OrderLineData lineData, int qc, int poly, int iron) {
    try {
      for (var po in globalPurchaseOrders) {
        for (var style in po.styles) {
          for (var deptList in style.departmentHourlyUpdates.values) {
            for (var hourly in deptList) {
              final match = hourly.lines.any((l) => l.buyerName == lineData.buyerName && l.style == lineData.style);
              if (match) {
                hourly.qcAchieve = (hourly.qcAchieve) + qc;
                hourly.polyAchieve = (hourly.polyAchieve) + poly;
                hourly.ironAchieve = (hourly.ironAchieve) + iron;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Finishing-to-admin sync error: $e');
    }
  }

  // Inline form widget - renders directly on page without popup
  Widget _buildInlineForm(
    BuildContext context,
    Order order,
    OrderLineData line,
    int lineIndex,
    int orderIndex,
  ) {
    String lineKey = '${orderIndex}_$lineIndex';
    
    // Get or create persistent controllers for this line
    if (!cuttingControllers.containsKey(lineKey)) {
      cuttingControllers[lineKey] = TextEditingController(
        text: savedValues[lineKey]?['cutting'] ?? 
            (line.dailyCutting == 0 ? '' : line.dailyCutting.toString()),
      );
    }
    if (!achieveControllers.containsKey(lineKey)) {
      achieveControllers[lineKey] = TextEditingController(
        text: savedValues[lineKey]?['achieve'] ?? 
            (line.achieve == 0 ? '' : line.achieve.toString()),
      );
    }
    if (!qcControllers.containsKey(lineKey)) {
      qcControllers[lineKey] = TextEditingController(
        text: savedValues[lineKey]?['qc'] ?? '',
      );
    }
    if (!polyControllers.containsKey(lineKey)) {
      polyControllers[lineKey] = TextEditingController(
        text: savedValues[lineKey]?['poly'] ?? '',
      );
    }
    if (!ironControllers.containsKey(lineKey)) {
      ironControllers[lineKey] = TextEditingController(
        text: savedValues[lineKey]?['iron'] ?? '',
      );
    }

    final cuttingController = cuttingControllers[lineKey]!;
    final achieveController = achieveControllers[lineKey]!;
    final qcController = qcControllers[lineKey]!;
    final polyController = polyControllers[lineKey]!;
    final ironController = ironControllers[lineKey]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        
        // Read-only field: Buyer Name
        const Text('Buyer Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey.shade100,
          ),
          child: Text(line.buyerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 12),
        
        // Read-only field: Style
        const Text('Style', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey.shade100,
          ),
          child: Text(line.style, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 12),
        
        // Read-only field: Color
        const Text('Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey.shade100,
          ),
          child: Text(line.color, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 12),
        
        // Read-only field: Target
        const Text('Target', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey.shade100,
          ),
          child: Text(line.target.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 16),
        
        // Department-specific input fields
        if (line.department == 'Cutting') ...[
          const Text('Daily Cutting', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: cuttingController,
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
        ] else if (line.department == 'Sewing') ...[
          const Text('Achieve', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: achieveController,
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
        ] else if (line.department == 'Finishing') ...[
          const Text('QC Achieve', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: qcController,
            decoration: InputDecoration(
              hintText: 'Enter QC quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          const Text('Poly Achieve', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: polyController,
            decoration: InputDecoration(
              hintText: 'Enter Poly quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          const Text('Iron Achieve', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: ironController,
            decoration: InputDecoration(
              hintText: 'Enter Iron quantity',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
        
        const SizedBox(height: 18),
        
        // Save button (full width green)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Get values from controllers before updating
              String cuttingValue = cuttingController.text;
              String achieveValue = achieveController.text;
              String qcValue = qcController.text;
              String polyValue = polyController.text;
              String ironValue = ironController.text;

              // Create updated line with new values
              final updatedLine = OrderLineData(
                buyerName: line.buyerName,
                style: line.style,
                item: line.item,
                color: line.color,
                target: line.target,
                operator: line.operator,
                shortOperator: line.shortOperator,
                bartechOperator: line.bartechOperator,
                bartechHelper: line.bartechHelper,
                unitNumber: line.unitNumber,
                lineNumber: line.lineNumber,
                department: line.department,
                dailyCutting: (line.department == 'Cutting')
                    ? (int.tryParse(cuttingValue) ?? 0)
                    : line.dailyCutting,
                achieve: (line.department == 'Sewing')
                    ? (int.tryParse(achieveValue) ?? 0)
                    : line.achieve,
                dailyInput: line.dailyInput,
                supervisorNotes: line.supervisorNotes,
                qcTarget: line.qcTarget,
                polyTarget: line.polyTarget,
                ironTarget: line.ironTarget,
              );

              // Sync to admin data
              if (line.department == 'Finishing') {
                final qc = int.tryParse(qcValue) ?? 0;
                final poly = int.tryParse(polyValue) ?? 0;
                final iron = int.tryParse(ironValue) ?? 0;
                _syncFinishingToAdmin(line, qc, poly, iron);
              }

              final orderIndex = orderManager.getAllOrders().indexOf(order);
              orderManager.updateOrderLine(orderIndex, lineIndex, updatedLine);
              _syncToAdminData(updatedLine, lineIndex);

              // Store values in persistent map AFTER saving
              if (!savedValues.containsKey(lineKey)) {
                savedValues[lineKey] = {};
              }
              savedValues[lineKey]!['cutting'] = cuttingValue;
              savedValues[lineKey]!['achieve'] = achieveValue;
              savedValues[lineKey]!['qc'] = qcValue;
              savedValues[lineKey]!['poly'] = polyValue;
              savedValues[lineKey]!['iron'] = ironValue;

              // Don't clear controllers - keep them with their current values
              // Update state to refresh UI
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data saved successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== SUPERVISOR DATA INPUT PAGE ====================

// ==================== MAIN APP ====================

class ProductionTrackerApp extends StatefulWidget {
  const ProductionTrackerApp({super.key});

  @override
  State<ProductionTrackerApp> createState() => _ProductionTrackerAppState();
}

class _ProductionTrackerAppState extends State<ProductionTrackerApp> {
  int selectedTabIndex =
      -1; // -1 = grid view, 0 = orders, 1 = production, 2 = reports

  // Sample data
  late List<PurchaseOrder> purchaseOrders;
  late List<ProductionReport> productionReports;

  @override
  void initState() {
    super.initState();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    // Use global storage so data persists across login/logout
    purchaseOrders = globalPurchaseOrders;
    productionReports = globalProductionReports;
    
    // Create default order in OrderManager for Admin-Supervisor data sync
    if (orderManager.getAllOrders().isEmpty) {
      final defaultOrder = Order(orderName: 'Production Order');
      orderManager.addOrder(defaultOrder);
    }
  }

  void _logout() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KTL Production Tracker'),
        centerTitle: true,
        elevation: 0,
        leading: selectedTabIndex == -1
            ? null
            : IconButton(
                icon: const Icon(Icons.chevron_left, size: 32),
                onPressed: () => setState(() => selectedTabIndex = -1),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _logout,
              child: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: selectedTabIndex == -1
          ? _buildNavigationGrid()
          : Column(
              children: [
                Expanded(
                  child: selectedTabIndex == 0
                      ? OrdersListView(
                          purchaseOrders: purchaseOrders,
                          onStyleSelected: _showStyleDetails,
                          onAddPO: _showAddPODialog,
                        )
                      : selectedTabIndex == 1
                      ? ProductionTrackingView(
                          purchaseOrders: purchaseOrders,
                          onReportAdded: (report) {
                            setState(() => productionReports.add(report));
                          },
                        )
                      : DailyReportsView(reports: productionReports),
                ),
              ],
            ),
    );
  }

  Widget _buildNavigationGrid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildNavCard(
              icon: Icons.shopping_cart,
              title: 'Orders',
              subtitle: 'View Purchase Orders',
              color: Colors.blue,
              onTap: () => setState(() => selectedTabIndex = 0),
            ),
            _buildNavCard(
              icon: Icons.build,
              title: 'Production',
              subtitle: 'Production Updates',
              color: Colors.green,
              onTap: () => setState(() => selectedTabIndex = 1),
            ),
            _buildNavCard(
              icon: Icons.assignment,
              title: 'Reports',
              subtitle: 'Daily Reports',
              color: Colors.orange,
              onTap: () => setState(() => selectedTabIndex = 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }



  void _showStyleDetails(StyleItem style, PurchaseOrder po) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDetailsSheet(
          style: style,
          po: po,
          onHourlySave: (purchaseOrder, styleItem, department) {
            _upsertReportFor(purchaseOrder, styleItem, department);
          },
        ),
      ),
    );
  }

  void _upsertReportFor(PurchaseOrder po, StyleItem style, String department) {
    final hourlyUpdates = style.departmentHourlyUpdates[department] ?? [];
    final totalInput = hourlyUpdates.fold(0, (sum, h) => sum + h.getTotalInput());
    final totalBalance = hourlyUpdates.fold(0, (sum, h) => sum + h.getTotalBalance());

    final report = ProductionReport(
      reportId: '${po.poNumber}-${style.styleId}-$department',
      poNumber: po.poNumber,
      styleId: style.styleId,
      styleName: style.styleCode,
      color: style.color,
      itemType: style.itemType,
      department: department,
      date: DateFormat('dd/MMMM/yy').format(DateTime.now()),
    );

    for (var h in hourlyUpdates) {
      report.hourlyData[h.hour] = h;
    }
    report.totalInput = totalInput;
    report.totalBalance = totalBalance;

    // Upsert into productionReports
    final existingIndex = productionReports.indexWhere((r) => r.poNumber == po.poNumber && r.styleId == style.styleId && r.department == department);
    setState(() {
      if (existingIndex >= 0) {
        productionReports[existingIndex] = report;
      } else {
        productionReports.add(report);
      }
    });

  
  }

  void _showAddPODialog() {
    final factoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: factoryController,
                  decoration: const InputDecoration(
                    labelText: 'Factory Name / Buyer Name',
                    //hintText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final factoryName = factoryController.text.trim();
                if (factoryName.isEmpty) return;
                
                final poNum = DateTime.now().millisecondsSinceEpoch.toString();
                final po = PurchaseOrder(poNumber: poNum, factory: factoryName);
                
                // Create automatic style/card with factory name
                final style = StyleItem(
                  styleId: DateTime.now().millisecondsSinceEpoch.toString(),
                  styleCode: factoryName,
                  color: '',
                  itemType: '',
                  totalQuantity: 0,
                );
                po.styles.add(style);
                
                setState(() {
                  purchaseOrders.add(po);
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

// ==================== ORDERS VIEW ====================

class OrdersListView extends StatefulWidget {
  final List<PurchaseOrder> purchaseOrders;
  final Function(StyleItem, PurchaseOrder) onStyleSelected;
  final VoidCallback onAddPO;

  const OrdersListView({
    super.key,
    required this.purchaseOrders,
    required this.onStyleSelected,
    required this.onAddPO,
  });

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MAIN CONTENT
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // bottom space for FAB
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Purchase Orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (widget.purchaseOrders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No purchase orders yet. Tap + to create one.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...widget.purchaseOrders
                    .map((po) => _buildPOCard(context, po))
                    .toList(),
            ],
          ),
        ),

        // FLOATING BUTTON
        Positioned(
          bottom: 70,
          right: 20,
          child: FloatingActionButton(
            onPressed: widget.onAddPO,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add,color: Colors.white,),
          ),
        ),
      ],
    );
  }

  Widget _buildPOCard(BuildContext context, PurchaseOrder po) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   po.factory,
            //   style: const TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
            const SizedBox(height: 12),

            if (po.styles.isEmpty)
              Text(
                'No cards available.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            else
              ...po.styles
                  .map((style) => _buildStyleTile(context, style, po))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleTile(
    BuildContext context,
    StyleItem style,
    PurchaseOrder po,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            po.factory,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => widget.onStyleSelected(style, po),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== STYLE DETAILS SHEET ====================

class StyleDetailsSheet extends StatelessWidget {
  final StyleItem style;
  final PurchaseOrder po;
  final void Function(PurchaseOrder, StyleItem, String)? onHourlySave;

  const StyleDetailsSheet({super.key, required this.style, required this.po, this.onHourlySave});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: Text(po.factory),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,            // selected tab text color
            unselectedLabelColor: Colors.white, 
            tabs: [
              Tab(text: '✂️ Cutting',),
              Tab(text: '🧵 Sewing'),
              Tab(text: '🔨 Finishing'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  DepartmentTrackingView(style: style, po: po, department: 'Cutting', onHourlySave: onHourlySave),
                  DepartmentTrackingView(style: style, po: po, department: 'Sewing', onHourlySave: onHourlySave),
                  DepartmentTrackingView(
                    style: style,
                    po: po,
                    department: 'Finishing',
                    onHourlySave: onHourlySave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DEPARTMENT TRACKING ====================

class DepartmentTrackingView extends StatefulWidget {
  final StyleItem style;
  final PurchaseOrder po;
  final String department;
  final void Function(PurchaseOrder, StyleItem, String)? onHourlySave;

  const DepartmentTrackingView({
    super.key,
    required this.style,
    required this.po,
    required this.department,
    this.onHourlySave,
  });

  @override
  State<DepartmentTrackingView> createState() => _DepartmentTrackingViewState();
}

class _DepartmentTrackingViewState extends State<DepartmentTrackingView> {
  late List<HourlyUpdate> hourlyUpdates;

  @override
  void initState() {
    super.initState();
    hourlyUpdates =
        widget.style.departmentHourlyUpdates[widget.department] ?? [];
    
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (hourlyUpdates.isEmpty) {
      // Create new hourly updates for today
      int totalHours = widget.department == 'Sewing'
          ? 9
          : widget.department == 'Finishing'
              ? 11
              : 8;
      for (int i = 1; i <= totalHours; i++) {
        final hourUpdate = HourlyUpdate(hour: i, date: today);
        // Add Unit 1 Line 1 initially
        hourUpdate.lines.add(
          LineData(lineNumber: 1, unitNumber: 1, target: 0, department: widget.department),
        );
        // For Sewing, also add Unit 2 Line 1 for all hours
        if (widget.department == 'Sewing') {
          hourUpdate.lines.add(
            LineData(lineNumber: 1, unitNumber: 2, target: 0, department: widget.department),
          );
        }
        hourlyUpdates.add(hourUpdate);
      }
      widget.style.departmentHourlyUpdates[widget.department] = hourlyUpdates;
    } else {
      // Check if any hourly update has a different date
      bool hasOldDate = hourlyUpdates.any((h) => h.date != today);
      if (hasOldDate) {
        // Clear old data and create new ones for today
        int totalHours = widget.department == 'Sewing'
            ? 9
            : widget.department == 'Finishing'
                ? 11
                : 8;
        hourlyUpdates.clear();
        for (int i = 1; i <= totalHours; i++) {
          final hourUpdate = HourlyUpdate(hour: i, date: today);
          // Add Unit 1 Line 1 initially
          hourUpdate.lines.add(
            LineData(lineNumber: 1, unitNumber: 1, target: 0, department: widget.department),
          );
          // For Sewing, also add Unit 2 Line 1 for all hours
          if (widget.department == 'Sewing') {
            hourUpdate.lines.add(
              LineData(lineNumber: 1, unitNumber: 2, target: 0, department: widget.department),
            );
          }
          hourlyUpdates.add(hourUpdate);
        }
        widget.style.departmentHourlyUpdates[widget.department] = hourlyUpdates;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalInput = hourlyUpdates.fold(0, (sum, h) => sum + h.getTotalInput());
    int totalBalance = hourlyUpdates.fold(
      0,
      (sum, h) => sum + h.getTotalBalance(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards with Date
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Date Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Date:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        hourlyUpdates.isNotEmpty 
                          ? hourlyUpdates.first.date
                          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    'Total Input (All Hours)',
                    '$totalInput Pcs',
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Total Balance',
                    totalBalance > 0 ? '$totalBalance Pcs' : '0 Pcs',
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  // _buildSummaryRow(
                  //   'Total Quantity',
                  //   '${widget.style.totalQuantity} Pcs',
                  //   Colors.purple,
                  // ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.department == 'Finishing')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hourly Finishing Input',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...hourlyUpdates.asMap().entries.map((entry) {
                  int index = entry.key;
                  HourlyUpdate update = entry.value;
                  return _buildFinishingHourCard(index, update);
                }).toList(),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hourly Line Tracking',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...hourlyUpdates.asMap().entries.map((entry) {
                  int index = entry.key;
                  HourlyUpdate update = entry.value;
                  return _buildHourCard(index, update);
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }

Widget _buildSummaryRow(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    //margin: const EdgeInsets.symmetric(vertical: 0),
    decoration: BoxDecoration(
      color: Colors.grey.shade100, // চাইলে remove করতে পারো
      borderRadius: BorderRadius.circular(2), // 👈 kona গোল
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}


  Widget _buildHourCard(int index, HourlyUpdate update) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  update.hour == 9 && widget.department == 'Sewing'
                      ? 'Overtime'
                      : 'Hour ${update.hour}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Total: ${update.getTotalInput()} Pcs',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...update.lines.asMap().entries.map((lineEntry) {
              return _buildLineDetail(update, lineEntry.value);
            }).toList(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showHourlyUpdateDialog(update),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Hour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishingHourCard(int index, HourlyUpdate update) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  update.hour == 11
                      ? 'Overtime'
                      : 'Hour ${update.hour}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Buyer Names display
            if (update.buyerNames.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buyers: ${update.buyerNames.join(", ")}',
                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (update.buyerNames.isNotEmpty) const SizedBox(height: 8),
            // Finishing Operator and Manpower display
            if (update.finishingOperator.isNotEmpty || update.totalFinishingManpower > 0)
              Row(
                children: [
                  if (update.finishingOperator.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Operator',
                              style: TextStyle(fontSize: 9, color: Colors.purple),
                            ),
                            Text(
                              update.finishingOperator,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (update.finishingOperator.isNotEmpty && update.totalFinishingManpower > 0)
                    const SizedBox(width: 8),
                  if (update.totalFinishingManpower > 0)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manpower',
                              style: TextStyle(fontSize: 9, color: Colors.orange),
                            ),
                            Text(
                              '${update.totalFinishingManpower} Workers',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            if (update.finishingOperator.isNotEmpty || update.totalFinishingManpower > 0)
              const SizedBox(height: 8),
            // Summary display
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✓ QC: ${update.qcTarget}/${update.qcAchieve}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '📦 Poly: ${update.polyTarget}/${update.polyAchieve}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🔩 Iron: ${update.ironTarget}/${update.ironAchieve}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showFinishingHourlyDialog(update),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Hour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineDetail(HourlyUpdate hour, LineData line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line-${line.lineNumber} Unit-${line.unitNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Balance: ${line.balance}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Buyer, Style, Item
          Row(
            
            children: [
              if (line.buyerName.isNotEmpty)
                Expanded(
                  child: Text(
                    'Buyer: ${line.buyerName}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              if (line.style.isNotEmpty)
                Expanded(
                  child: Text(
                    'Style: ${line.style}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              if (line.item.isNotEmpty)
                Expanded(
                  child: Text(
                    'Item: ${line.item}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Target, Achieve
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target: ${line.target}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              Expanded(
                child: Text(
                  'Achieve: ${line.achieve}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          if (line.operator.isNotEmpty ||
              line.shortOperator.isNotEmpty ||
              line.helper.isNotEmpty ||
              line.shortHelper.isNotEmpty)
            const SizedBox(height: 6),
          // Operator & Helper info
          if (line.operator.isNotEmpty || line.shortOperator.isNotEmpty)
            Row(
              children: [
                if (line.operator.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Operator: ${line.operator}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                if (line.shortOperator.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Short Op: ${line.shortOperator}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          if (line.helper.isNotEmpty || line.shortHelper.isNotEmpty)
            Row(
              children: [
                if (line.helper.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Helper: ${line.helper}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                if (line.shortHelper.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Short Helper: ${line.shortHelper}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          // Bartech Section - Show for Sewing (always show for sewing)
          if (widget.department == 'Sewing')
            Row(
              children: [
                if (line.bartechOperator.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Bartech Opt: ${line.bartechOperator}',
                      style: const TextStyle(
                        fontSize: 10,
                        //color: Colors.orange,
                        //fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (line.bartechHelper.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Bartech Helper: ${line.bartechHelper}',
                      style: const TextStyle(
                        fontSize: 10,
                        //color: Colors.orange,
                       // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showHourlyUpdateDialog(HourlyUpdate update) {
    // Route to a department-specific input page
    if (widget.department == 'Finishing') {
      _showFinishingHourlyDialog(update);
      return;
    }

    if (widget.department == 'Cutting') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HourlyInputPage(
            hourlyUpdate: update,
            department: widget.department,
            onSave: () {
              setState(() {});
              if (widget.onHourlySave != null) {
                widget.onHourlySave!(widget.po, widget.style, widget.department);
              }
            },
          ),
        ),
      );
      return;
    }
    // For Sewing keep the original design (HourlyInputPage)
    if (widget.department == 'Sewing') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HourlyInputPage(
            hourlyUpdate: update,
            department: widget.department,
            onSave: () {
              setState(() {});
              if (widget.onHourlySave != null) {
                widget.onHourlySave!(widget.po, widget.style, widget.department);
              }
            },
          ),
        ),
      );
      return;
    }

    // Fallback to generic HourlyInputPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HourlyInputPage(
          hourlyUpdate: update,
          department: widget.department,
          onSave: () {
            setState(() {});
            if (widget.onHourlySave != null) {
              widget.onHourlySave!(widget.po, widget.style, widget.department);
            }
          },
        ),
      ),
    );
  }

  void _showFinishingHourlyDialog(HourlyUpdate update) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinishingInputPage(
          update: update,
          onSave: () {
            setState(() {});
            if (widget.onHourlySave != null) {
              widget.onHourlySave!(widget.po, widget.style, widget.department);
            }
          },
        ),
      ),
    );
  }
}

class FinishingInputPage extends StatefulWidget {
  final HourlyUpdate update;
  final VoidCallback onSave;

  const FinishingInputPage({
    super.key,
    required this.update,
    required this.onSave,
  });

  @override
  State<FinishingInputPage> createState() => _FinishingInputPageState();
}



// ==================== SEWING INPUT PAGE (Separate) ====================

class SewingInputPage extends StatefulWidget {
  final HourlyUpdate update;
  final VoidCallback onSave;

  const SewingInputPage({super.key, required this.update, required this.onSave});

  @override
  State<SewingInputPage> createState() => _SewingInputPageState();
}

class _SewingInputPageState extends State<SewingInputPage> {
  late TextEditingController styleController;
  late TextEditingController colorController;
  late TextEditingController itemController;

  @override
  void initState() {
    super.initState();
    styleController = TextEditingController(text: widget.update.style);
    colorController = TextEditingController(text: widget.update.color);
    itemController = TextEditingController(text: widget.update.item);
  }

  @override
  void dispose() {
    styleController.dispose();
    colorController.dispose();
    itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text('Hour ${widget.update.hour} - Sewing'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Style / Color / Item', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: styleController, decoration: const InputDecoration(labelText: 'Style')),
                  const SizedBox(height: 8),
                  TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Color')),
                  const SizedBox(height: 8),
                  TextField(controller: itemController, decoration: const InputDecoration(labelText: 'Item')),
                  const SizedBox(height: 12),
                  // Per-line sewing fields: Achieve and Daily Input, similar to finishing separated inputs
                  ...widget.update.lines.map((line) {
                    final achieveController = TextEditingController(text: line.achieve == 0 ? '' : line.achieve.toString());
                    final inputController = TextEditingController(text: line.dailyInput == 0 ? '' : line.dailyInput.toString());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.style.isNotEmpty ? line.style : 'Line ${line.lineNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(controller: achieveController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Achieve')),
                            const SizedBox(height: 8),
                            TextField(controller: inputController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Input')),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.update.style = styleController.text;
                      widget.update.color = colorController.text;
                      widget.update.item = itemController.text;
                      widget.onSave();
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishingInputPageState extends State<FinishingInputPage> {
  late TextEditingController qcTargetController;
  late TextEditingController qcAchieveController;
  late TextEditingController polyTargetController;
  late TextEditingController polyAchieveController;
  late TextEditingController ironTargetController;
  late TextEditingController ironAchieveController;
  late TextEditingController manpowerController;
  late TextEditingController operatorController;
  late TextEditingController styleController;
  late TextEditingController colorController;
  late TextEditingController itemController;

  final buyerOptions = ['Winner Jeans', 'Dreamtex', 'Fashion Fast'];

  @override
  void initState() {
    super.initState();
    qcTargetController = TextEditingController(text: widget.update.qcTarget.toString());
    qcAchieveController = TextEditingController(text: widget.update.qcAchieve.toString());
    polyTargetController = TextEditingController(text: widget.update.polyTarget.toString());
    polyAchieveController = TextEditingController(text: widget.update.polyAchieve.toString());
    ironTargetController = TextEditingController(text: widget.update.ironTarget.toString());
    ironAchieveController = TextEditingController(text: widget.update.ironAchieve.toString());
    manpowerController = TextEditingController(text: widget.update.totalFinishingManpower.toString());
    operatorController = TextEditingController(text: widget.update.finishingOperator);
    styleController = TextEditingController(text: widget.update.style);
    colorController = TextEditingController(text: widget.update.color);
    itemController = TextEditingController(text: widget.update.item);
  }

  @override
  void dispose() {
    qcTargetController.dispose();
    qcAchieveController.dispose();
    polyTargetController.dispose();
    polyAchieveController.dispose();
    ironTargetController.dispose();
    ironAchieveController.dispose();
    manpowerController.dispose();
    operatorController.dispose();
    styleController.dispose();
    colorController.dispose();
    itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          title: Text('Hour ${widget.update.hour == 11 ? 'Overtime' : widget.update.hour} - Finishing'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyers
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Buyer Name (Select 2-3)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                          const SizedBox(height: 8),
                          Column(
                            children: buyerOptions.map((buyer) {
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: widget.update.buyerNames.contains(buyer),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) widget.update.buyerNames.add(buyer);
                                    else widget.update.buyerNames.remove(buyer);
                                  });
                                },
                                title: Text(buyer, style: const TextStyle(fontSize: 12)),
                                activeColor: Colors.blue,
                              );
                            }).toList(),
                          ),
                          Text('Selected: ${widget.update.buyerNames.isNotEmpty ? widget.update.buyerNames.join(", ") : "None"}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blue)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQCField(),
                    const SizedBox(height: 16),
                    _buildPolyField(),
                    const SizedBox(height: 16),
                    _buildIronField(),
                    const SizedBox(height: 16),
                    // Style/Color/Item
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Style, Color, Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                          const SizedBox(height: 10),
                          TextField(controller: styleController, decoration: InputDecoration(labelText: 'Style', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.style = val),
                          const SizedBox(height: 10),
                          TextField(controller: colorController, decoration: InputDecoration(labelText: 'Color', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.color = val),
                          const SizedBox(height: 10),
                          TextField(controller: itemController, decoration: InputDecoration(labelText: 'Item', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.item = val),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Manpower + Operator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Finishing Manpower', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                        const SizedBox(height: 8),
                        TextField(keyboardType: TextInputType.number, controller: manpowerController, decoration: InputDecoration(labelText: 'Number of Workers', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.totalFinishingManpower = int.tryParse(val) ?? 0),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Finishing Operator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple[200]!)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Finishing Operator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple)),
                        const SizedBox(height: 8),
                        TextField(keyboardType: TextInputType.text, controller: operatorController, decoration: InputDecoration(labelText: 'Operator', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.finishingOperator = val),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[400], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () {
                    // Sync finishing summary into OrderManager so Finishing supervisor can see it
                    try {
                      final orders = orderManager.getAllOrders();
                      if (orders.isNotEmpty) {
                        final order = orders[0];
                        final finishingTotal = widget.update.qcAchieve + widget.update.polyAchieve + widget.update.ironAchieve;
                        // Try to find existing finishing line by style+item+color
                        final matchIndex = order.lines.indexWhere((ol) =>
                            ol.department == 'Finishing' &&
                            ol.style == widget.update.style &&
                            ol.item == widget.update.item &&
                            ol.color == widget.update.color);
                        if (matchIndex != -1) {
                          final existing = order.lines[matchIndex];
                          existing.achieve = existing.achieve + finishingTotal;
                          existing.dailyInput = existing.dailyInput + finishingTotal;
                          existing.operator = widget.update.finishingOperator;
                          // update finishing targets too
                          existing.qcTarget = widget.update.qcTarget;
                          existing.polyTarget = widget.update.polyTarget;
                          existing.ironTarget = widget.update.ironTarget;
                        } else {
                          final orderLine = OrderLineData(
                            buyerName: widget.update.buyerNames.isNotEmpty ? widget.update.buyerNames.first : '',
                            style: widget.update.style,
                            item: widget.update.item,
                            color: widget.update.color,
                            target: 0,
                            operator: widget.update.finishingOperator,
                            shortOperator: '',
                            bartechOperator: '',
                            bartechHelper: '',
                            dailyCutting: 0,
                            dailyInput: finishingTotal,
                            department: 'Finishing',
                            achieve: finishingTotal,
                            qcTarget: widget.update.qcTarget,
                            polyTarget: widget.update.polyTarget,
                            ironTarget: widget.update.ironTarget,
                          );
                          order.lines.add(orderLine);
                        }
                      }
                    } catch (e) {
                      print('Finishing sync error: $e');
                    }
                    // Also sync finishing achieves/targets into admin globalPurchaseOrders HourlyUpdate entries
                    try {
                      for (var po in globalPurchaseOrders) {
                        for (var style in po.styles) {
                          // Only update the Finishing department hourly updates for the specific hour
                          final finishingList = style.departmentHourlyUpdates['Finishing'] ?? [];
                          for (var hourly in finishingList) {
                            final buyerMatch = widget.update.buyerNames.isEmpty
                                ? true
                                : (hourly.buyerNames.isNotEmpty && hourly.buyerNames.first == widget.update.buyerNames.first);
                            if (hourly.hour == widget.update.hour && hourly.style == widget.update.style && buyerMatch) {
                              hourly.qcAchieve = hourly.qcAchieve + widget.update.qcAchieve;
                              hourly.polyAchieve = hourly.polyAchieve + widget.update.polyAchieve;
                              hourly.ironAchieve = hourly.ironAchieve + widget.update.ironAchieve;
                              // Update targets only for the specific hour so targets are unique per hour
                              hourly.qcTarget = widget.update.qcTarget;
                              hourly.polyTarget = widget.update.polyTarget;
                              hourly.ironTarget = widget.update.ironTarget;
                            }
                          }
                        }
                      }
                    } catch (e) {
                      print('Finishing admin-hourly sync error: $e');
                    }
                    widget.onSave();
                    Navigator.pop(context);
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)), child: const Text('Save')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQCField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✓ QC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: qcTargetController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Total Target', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.qcTarget = int.tryParse(val) ?? 0)),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: qcAchieveController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Achieve', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.qcAchieve = int.tryParse(val) ?? 0)),
        ])
      ]),
    );
  }

  Widget _buildPolyField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📦 Poly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: polyTargetController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Total Target', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.polyTarget = int.tryParse(val) ?? 0)),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: polyAchieveController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Achieve', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.polyAchieve = int.tryParse(val) ?? 0)),
        ])
      ]),
    );
  }

  Widget _buildIronField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔩 Iron', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: ironTargetController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Total Target', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.ironTarget = int.tryParse(val) ?? 0)),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: ironAchieveController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Achieve', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: const TextStyle(fontSize: 12), onChanged: (val) => widget.update.ironAchieve = int.tryParse(val) ?? 0)),
        ])
      ]),
    );
  }
}

// ==================== PRODUCTION TRACKING ====================

class ProductionTrackingView extends StatefulWidget {
  final List<PurchaseOrder> purchaseOrders;
  final Function(ProductionReport) onReportAdded;

  const ProductionTrackingView({
    super.key,
    required this.purchaseOrders,
    required this.onReportAdded,
  });

  @override
  State<ProductionTrackingView> createState() => _ProductionTrackingViewState();
}

class _ProductionTrackingViewState extends State<ProductionTrackingView> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Production Update',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...widget.purchaseOrders.expand((po) => po.styles.map((style) => _buildQuickUpdateCard(po, style))).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickUpdateCard(PurchaseOrder po, StyleItem style) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                po.factory,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _showDepartmentReport(po, style, 'Cutting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cutting'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _showDepartmentReport(po, style, 'Sewing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Sewing'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _showDepartmentReport(po, style, 'Finishing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Finishing'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDepartmentReport(
    PurchaseOrder po,
    StyleItem style,
    String department,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportDialog(
          po: po,
          style: style,
          department: department,
          onAdd: widget.onReportAdded,
        ),
      ),
    );
  }
}

// ==================== DAILY REPORTS ====================

class DailyReportsView extends StatefulWidget {
  final List<ProductionReport> reports;

  const DailyReportsView({super.key, required this.reports});

  @override
  State<DailyReportsView> createState() => _DailyReportsViewState();
}

class _DailyReportsViewState extends State<DailyReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.grey[100],
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: '✂️ Cutting'),
              Tab(text: '🧵 Sewing'),
              Tab(text: '✓ Finishing'),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDepartmentReportTab('Cutting'),
              _buildDepartmentReportTab('Sewing'),
              _buildDepartmentReportTab('Finishing'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentReportTab(String department) {
    final deptReports = widget.reports.where((r) => r.department == department).toList();
    
    // Group by style
    final groupedByStyle = <String, List<ProductionReport>>{};
    for (final report in deptReports) {
      final key = '${report.poNumber}-${report.styleId}';
      groupedByStyle.putIfAbsent(key, () => []).add(report);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$department Reports',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (deptReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No $department reports yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...groupedByStyle.entries.map(
              (entry) {
                return _buildStyleReportCard(entry.value);
              },
            ).toList(),
        ],
      ),
    );
  }

  Widget _buildStyleReportCard(List<ProductionReport> reports) {
    return ReportCardDisplay(reports: reports);
  }
}

// ==================== REPORT CARD DISPLAY ====================

class ReportCardDisplay extends StatefulWidget {
  final List<ProductionReport> reports;

  const ReportCardDisplay({required this.reports, super.key});

  @override
  State<ReportCardDisplay> createState() => _ReportCardDisplayState();
}

class _ReportCardDisplayState extends State<ReportCardDisplay> with SingleTickerProviderStateMixin {
  bool showDailyView = false;
  int selectedUnitTab = -1; // -1 means no unit selected (default view), otherwise unit number
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) return const SizedBox.shrink();
    
    final firstReport = widget.reports.first;
    
    // Ensure all reports are from the same department
    final department = firstReport.department;
    final sameDepReports = widget.reports.where((r) => r.department == department).toList();
    
    if (sameDepReports.isEmpty) return const SizedBox.shrink();

    // For Sewing, get all unique units
    final allUnits = <int>{};
    if (department == 'Sewing') {
      for (final report in sameDepReports) {
        for (final hourlyUpdate in report.hourlyData.values) {
          for (final line in hourlyUpdate.lines) {
            allUnits.add(line.unitNumber);
          }
        }
      }
    }
    final sortedUnits = allUnits.toList()..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${firstReport.date}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Text(
                    //   'Date: ${firstReport.date}',
                    //   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    // ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      showDailyView = !showDailyView;
                    });
                  },
                  icon: Icon(showDailyView ? Icons.list : Icons.calendar_today, size: 14),
                  label: Text(showDailyView ? 'View Hourly' : 'View Daily'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            // Unit tabs for Sewing
            if (department == 'Sewing' && sortedUnits.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedUnitTab = -1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: selectedUnitTab == -1 ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedUnitTab == -1 ? Colors.blue : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            'All Units',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selectedUnitTab == -1 ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      ...sortedUnits.map((unit) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedUnitTab = unit;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: selectedUnitTab == unit ? Colors.blue : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedUnitTab == unit ? Colors.blue : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              'Unit $unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selectedUnitTab == unit ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...sameDepReports.map((report) {
              return Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Department header with buyer, style, color
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.department,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Show buyers/style/color/item using hourlyData when available for any department
                              // For Sewing with selected unit, filter data accordingly
                              if (report.hourlyData.isNotEmpty && report.hourlyData.values.any((h) => h.buyerNames.isNotEmpty))
                                _buildInfoChip('🏭 Buyer', _getFilteredHourlyData(report.hourlyData, report.department).values
                                  .where((h) => h.buyerNames.isNotEmpty)
                                  .map((h) => h.buyerNames.join(', '))
                                  .toList()
                                  .join(', ')),
                              _buildInfoChip('🎨 Style', 
                                report.hourlyData.isNotEmpty
                                  ? (report.hourlyData.values.firstWhere((h) => h.style.isNotEmpty, orElse: () => report.hourlyData.values.first).style.isNotEmpty 
                                    ? report.hourlyData.values.firstWhere((h) => h.style.isNotEmpty, orElse: () => report.hourlyData.values.first).style
                                    : report.styleName)
                                  : report.styleName),
                              _buildInfoChip('🌈 Color', 
                                report.hourlyData.isNotEmpty
                                  ? (report.hourlyData.values.firstWhere((h) => h.color.isNotEmpty, orElse: () => report.hourlyData.values.first).color.isNotEmpty 
                                    ? report.hourlyData.values.firstWhere((h) => h.color.isNotEmpty, orElse: () => report.hourlyData.values.first).color
                                    : report.color)
                                  : report.color),
                              _buildInfoChip('📦 Item', 
                                report.hourlyData.isNotEmpty
                                  ? (report.hourlyData.values.firstWhere((h) => h.item.isNotEmpty, orElse: () => report.hourlyData.values.first).item.isNotEmpty 
                                    ? report.hourlyData.values.firstWhere((h) => h.item.isNotEmpty, orElse: () => report.hourlyData.values.first).item
                                    : report.itemType)
                                  : report.itemType),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Stats
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildReportStat(
                          'Target',
                          '${_calculateDailyTarget(report, selectedUnit: selectedUnitTab)} Pcs',
                        ),
                        _buildReportStat(
                          'Achieve',
                          '${report.getDailyTotal(selectedUnit: selectedUnitTab)} Pcs',
                        ),
                        _buildReportStat(
                          'Balance',
                          _calculateBalance(report, selectedUnit: selectedUnitTab) > 0 ? '${_calculateBalance(report, selectedUnit: selectedUnitTab)} Pcs' : '0 Pcs',
                        ),
                      ],
                    ),
                    // Hourly breakdown chart or Daily Summary
                    if (report.hourlyData.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: showDailyView
                          ? _buildReportDailySummary(_getFilteredHourlyData(report.hourlyData, report.department), report.department)
                              : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hourly Production',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                _buildHourlyBarChart(_getFilteredHourlyData(report.hourlyData, report.department), report.department),
                              ],
                            ),
                      ),
                  ],
                ),
              );
            }).toList(),
            
          ],
        ),
        
      ),
      
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 10),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  // Helper method to filter hourly data by selected unit (for Sewing)
  Map<int, HourlyUpdate> _getFilteredHourlyData(Map<int, HourlyUpdate> hourlyData, String department) {
    if (department != 'Sewing' || selectedUnitTab == -1) {
      return hourlyData;
    }
    
    final filteredData = <int, HourlyUpdate>{};
    for (final entry in hourlyData.entries) {
      final hour = entry.key;
      final update = entry.value;
      
      // Filter lines by unit
      final filteredLines = update.lines.where((line) => line.unitNumber == selectedUnitTab).toList();
      
      // Always include the hour, even if unit has no data for this hour
      // If no lines exist for this unit, create a placeholder
      if (filteredLines.isEmpty) {
        filteredLines.add(
          LineData(lineNumber: 1, unitNumber: selectedUnitTab, target: 0, department: department),
        );
      }
      
      // Create a new HourlyUpdate with filtered lines
      final filteredUpdate = HourlyUpdate(
        hour: update.hour,
        notes: update.notes,
        date: update.date,
      )..lines = filteredLines
       ..buyerNames = update.buyerNames
       ..style = update.style
       ..color = update.color
       ..item = update.item
       ..qcTarget = update.qcTarget
       ..qcAchieve = update.qcAchieve
       ..polyTarget = update.polyTarget
       ..polyAchieve = update.polyAchieve
       ..ironTarget = update.ironTarget
       ..ironAchieve = update.ironAchieve
       ..finishingOperator = update.finishingOperator
       ..totalFinishingManpower = update.totalFinishingManpower;
      
      filteredData[hour] = filteredUpdate;
    }
    
    return filteredData;
  }

  Widget _buildReportStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHourlyBarChart(Map<int, HourlyUpdate> hourlyData, String department) {
    final sortedHours = hourlyData.keys.toList()..sort();
    final barChartData = <BarChartGroupData>[];

    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i];
      final update = hourlyData[hour]!;

      if (department == 'Finishing') {
        final qc = update.qcAchieve.toDouble();
        final poly = update.polyAchieve.toDouble();
        final iron = update.ironAchieve.toDouble();

        barChartData.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: qc, color: Colors.green, width: 6),
              BarChartRodData(toY: poly, color: Colors.blue, width: 6),
              BarChartRodData(toY: iron, color: Colors.purple, width: 6),
            ],
          ),
        );
      } else {
        final achieve = update.getTotalInput().toDouble();
        final target = update.lines.fold<int>(0, (sum, line) => sum + line.target).toDouble();

        barChartData.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: target, color: Colors.orange.withOpacity(0.7), width: 6),
              BarChartRodData(toY: achieve, color: Colors.green, width: 6),
            ],
          ),
        );
      }
    }

    double maxY = 0;
    for (final data in barChartData) {
      for (final rod in data.barRods) {
        if (rod.toY > maxY) maxY = rod.toY;
      }
    }
    maxY = (maxY + 10);

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedHours.length) return const Text('');
                        final hour = sortedHours[index];
                        return Text('${hour}h', style: const TextStyle(fontSize: 8));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final intVal = value.toInt();
                        final maxInt = maxY.toInt();
                        final mid = (maxInt / 2).round();
                        if (intVal == 0 || intVal == mid || intVal == maxInt) {
                          return Text('$intVal', style: const TextStyle(fontSize: 8));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barChartData,
                maxY: maxY,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: department == 'Finishing'
                  ? [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      const Text('QC', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 12),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      const Text('Poly', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 12),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      const Text('Iron', style: TextStyle(fontSize: 8)),
                    ]
                  : [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      const Text('Target', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 12),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      const Text('Achieve', style: TextStyle(fontSize: 8)),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDailySummary(Map<int, HourlyUpdate> hourlyData, String department) {
    if (hourlyData.isEmpty) return const SizedBox.shrink();

    int totalQcTarget = 0, totalQcAchieve = 0;
    int totalPolyTarget = 0, totalPolyAchieve = 0;
    int totalIronTarget = 0, totalIronAchieve = 0;
    int totalTarget = 0, totalAchieve = 0;
    Set<String> allBuyers = {};
    String style = '', color = '', item = '';

    for (var h in hourlyData.values) {
      allBuyers.addAll(h.buyerNames);
      if (style.isEmpty && h.style.isNotEmpty) style = h.style;
      if (color.isEmpty && h.color.isNotEmpty) color = h.color;
      if (item.isEmpty && h.item.isNotEmpty) item = h.item;

      // Only sum up department-specific data
      if (department == 'Finishing') {
        totalQcTarget += h.qcTarget;
        totalQcAchieve += h.qcAchieve;
        totalPolyTarget += h.polyTarget;
        totalPolyAchieve += h.polyAchieve;
        totalIronTarget += h.ironTarget;
        totalIronAchieve += h.ironAchieve;
      } else if (department == 'Cutting' || department == 'Sewing') {
        // For Cutting and Sewing, sum the lines data
        totalTarget += h.lines.fold<int>(0, (sum, line) => sum + line.target);
        totalAchieve += h.getTotalInput();
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Total Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber)),
          const SizedBox(height: 8),
          if (allBuyers.isNotEmpty)

          if (style.isNotEmpty || color.isNotEmpty || item.isNotEmpty)
  
          if (department == 'Finishing')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('QC: $totalQcAchieve/$totalQcTarget', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Poly: $totalPolyAchieve/$totalPolyTarget', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Iron: $totalIronAchieve/$totalIronTarget', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            )
          else if (department == 'Cutting' || department == 'Sewing')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target: $totalTarget Pcs', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Achieve: $totalAchieve Pcs', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          const SizedBox(height: 12),
          // Daily summary chart - show per-department chart
          Container(
            height: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: department == 'Finishing'
                ? _buildFinishingDailyChart(totalQcTarget, totalQcAchieve, totalPolyTarget, totalPolyAchieve, totalIronTarget, totalIronAchieve)
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('Daily', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final intVal = value.toInt();
                              final maxInt = ((totalTarget > totalAchieve ? totalTarget : totalAchieve).toDouble() + 50).toInt();
                              final mid = (maxInt / 2).round();
                              if (intVal == 0 || intVal == mid || intVal == maxInt) {
                                return Text('$intVal', style: const TextStyle(fontSize: 9));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: (totalTarget).toDouble(),
                              color: Colors.orange.withOpacity(0.7),
                              width: 30,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: (totalAchieve).toDouble(),
                              color: Colors.green,
                              width: 30,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                            ),
                          ],
                        ),
                      ],
                      maxY: (totalTarget > totalAchieve ? totalTarget : totalAchieve).toDouble() + 50,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Target: $totalTarget', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                const SizedBox(width: 20),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Achieve: $totalAchieve', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishingDailyChart(
    int qcTarget,
    int qcAchieve,
    int polyTarget,
    int polyAchieve,
    int ironTarget,
    int ironAchieve,
  ) {
    final groups = <BarChartGroupData>[];

    groups.add(
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(toY: qcTarget.toDouble(), color: Colors.orange.withOpacity(0.7), width: 12),
          BarChartRodData(toY: qcAchieve.toDouble(), color: Colors.green, width: 12),
        ],
      ),
    );
    groups.add(
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(toY: polyTarget.toDouble(), color: Colors.orange.withOpacity(0.7), width: 12),
          BarChartRodData(toY: polyAchieve.toDouble(), color: Colors.blue, width: 12),
        ],
      ),
    );
    groups.add(
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(toY: ironTarget.toDouble(), color: Colors.orange.withOpacity(0.7), width: 12),
          BarChartRodData(toY: ironAchieve.toDouble(), color: Colors.purple, width: 12),
        ],
      ),
    );

    double maxY = 0;
    for (final g in groups) {
      for (final r in g.barRods) {
        if (r.toY > maxY) maxY = r.toY;
      }
    }
    maxY = maxY + 10;

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx == 0) return const Text('QC', style: TextStyle(fontSize: 10));
                      if (idx == 1) return const Text('Poly', style: TextStyle(fontSize: 10));
                      if (idx == 2) return const Text('Iron', style: TextStyle(fontSize: 10));
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final intVal = value.toInt();
                      final maxInt = maxY.toInt();
                      final mid = (maxInt / 2).round();
                      if (intVal == 0 || intVal == mid || intVal == maxInt) return Text('$intVal', style: const TextStyle(fontSize: 9));
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: groups,
              maxY: maxY,
              groupsSpace: 20,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              const Text('Target', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 12),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              const Text('QC Achieve', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 12),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              const Text('Poly Achieve', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 12),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              const Text('Iron Achieve', style: TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  int _calculateDailyTarget(ProductionReport report, {int selectedUnit = -1}) {
    int totalTarget = 0;
    for (var h in report.hourlyData.values) {
      if (selectedUnit <= 0) {
        // No unit filter, sum all
        totalTarget += h.lines.fold<int>(0, (sum, line) => sum + line.target);
      } else {
        // Filter by unit (for Sewing department)
        totalTarget += h.lines.where((line) => line.unitNumber == selectedUnit).fold<int>(0, (sum, line) => sum + line.target);
      }
    }
    return totalTarget;
  }

  int _calculateBalance(ProductionReport report, {int selectedUnit = -1}) {
    int target = _calculateDailyTarget(report, selectedUnit: selectedUnit);
    int achieve = report.getDailyTotal(selectedUnit: selectedUnit);
    return target - achieve;
  }
}

// ==================== DAILY REPORT DIALOG ====================

class DailyReportDialog extends StatefulWidget {
  final PurchaseOrder po;
  final StyleItem style;
  final String department;
  final Function(ProductionReport) onAdd;

  const DailyReportDialog({
    super.key,
    required this.po,
    required this.style,
    required this.department,
    required this.onAdd,
  });

  @override
  State<DailyReportDialog> createState() => _DailyReportDialogState();
}

class _DailyReportDialogState extends State<DailyReportDialog> {
  bool showDailyView = false; // Toggle between hourly and daily view

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hourlyUpdates =
        widget.style.departmentHourlyUpdates[widget.department] ?? [];
    final totalInput = hourlyUpdates.fold(
      0,
      (sum, h) => sum + h.getTotalInput(),
    );
    final totalBalance = hourlyUpdates.fold(
      0,
      (sum, h) => sum + h.getTotalBalance(),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.department} Report',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date:'),
                      Text(
                        hourlyUpdates.isNotEmpty 
                          ? hourlyUpdates.first.date
                          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Daily Input:'),
                      Text(
                        '$totalInput Pcs',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Balance:'),
                      Text(
                        '$totalBalance Pcs',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showDailyView ? 'Daily Summary:' : 'Hourly Breakdown:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            
              ],
            ),
            const SizedBox(height: 12),
            if (showDailyView)
              _buildDailySummary(hourlyUpdates, widget.department)
            else if (hourlyUpdates.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: const Text(
                    'No hourly updates recorded for this department yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...hourlyUpdates.map((h) {
              if (widget.department == 'Finishing') {
                // Show Finishing data
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.hour == 11 ? 'Overtime' : 'Hour ${h.hour}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Style, Color, Item
                        if (h.style.isNotEmpty || h.color.isNotEmpty || h.item.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple[300]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.category, size: 16, color: Colors.purple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${h.style.isNotEmpty ? h.style : '---'} | ${h.color.isNotEmpty ? h.color : '---'} | ${h.item.isNotEmpty ? h.item : '---'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.purple),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Buyer Names
                        if (h.buyerNames.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.business, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Buyers: ${h.buyerNames.join(", ")}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        // Operator and Manpower
                        if (h.finishingOperator.isNotEmpty || h.totalFinishingManpower > 0)
                          Row(
                            children: [
                              if (h.finishingOperator.isNotEmpty)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.purple[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Operator',
                                          style: TextStyle(fontSize: 9, color: Colors.purple),
                                        ),
                                        Text(
                                          h.finishingOperator,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (h.finishingOperator.isNotEmpty && h.totalFinishingManpower > 0)
                                const SizedBox(width: 8),
                              if (h.totalFinishingManpower > 0)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Manpower',
                                          style: TextStyle(fontSize: 9, color: Colors.orange),
                                        ),
                                        Text(
                                          '${h.totalFinishingManpower} Workers',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (h.finishingOperator.isNotEmpty || h.totalFinishingManpower > 0)
                          const SizedBox(height: 12),
                        // QC Section
                        _buildFinishingReportField(
                          '✓ QC',
                          h.qcTarget,
                          h.qcAchieve,
                        ),
                        const SizedBox(height: 10),
                        // Poly Section
                        _buildFinishingReportField(
                          '📦 Poly',
                          h.polyTarget,
                          h.polyAchieve,
                        ),
                        const SizedBox(height: 10),
                        // Iron Section
                        _buildFinishingReportField(
                          '🔩 Iron',
                          h.ironTarget,
                          h.ironAchieve,
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Show Line tracking data (original)
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              h.hour == 9 && widget.department == 'Sewing'
                                  ? 'Overtime'
                                  : 'Hour ${h.hour}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Total: ${h.getTotalInput()} Pcs',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...h.lines.map((line) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      widget.department == 'Sewing'
                                          ? 'Line ${line.lineNumber} - Unit ${line.unitNumber}'
                                          : (line.style.isNotEmpty ? line.style : ''),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Achieve: ${line.achieve}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (line.buyerName.isNotEmpty)
                                Text(
                                  'Buyer: ${line.buyerName}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (line.style.isNotEmpty)
                                Text(
                                  'Style: ${line.style}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (line.item.isNotEmpty)
                                Text(
                                  'Item: ${line.item}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (widget.department == 'Cutting' &&
                                  line.color.isNotEmpty)
                                Text(
                                  'Color: ${line.color}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Target: ${line.target}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'Balance: ${line.balance}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.department == 'Cutting')
                                Column(
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Daily Cutting: ${line.achieve}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Daily Input: ${line.dailyInput}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Input: ${line.totalInput}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (line.operator.isNotEmpty ||
                                  line.shortOperator.isNotEmpty ||
                                  line.helper.isNotEmpty ||
                                  line.shortHelper.isNotEmpty)
                                const SizedBox(height: 6),
                              if (line.operator.isNotEmpty ||
                                  line.shortOperator.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (line.operator.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Operator: ${line.operator}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    if (line.shortOperator.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Short Op: ${line.shortOperator}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              if (line.helper.isNotEmpty ||
                                  line.shortHelper.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (line.helper.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Helper: ${line.helper}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    if (line.shortHelper.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          'Short Helper: ${line.shortHelper}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              // Bartech Section - Show for Sewing
                              if (widget.department == 'Sewing' &&
                                  (line.bartechOperator.isNotEmpty ||
                                      line.bartechHelper.isNotEmpty))
                                Column(
                                  children: [
                                    //const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (line.bartechOperator
                                            .isNotEmpty)
                                          Expanded(
                                            child: Text(
                                              'Bartech Op: ${line.bartechOperator}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (line.bartechHelper.isNotEmpty)
                                          Expanded(
                                            child: Text(
                                              'Bartech Helper: ${line.bartechHelper}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w500,
                                                //color: Colors.orange[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }
            }).toList(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                final report = ProductionReport(
                  reportId: DateTime.now().toString(),
                  poNumber: widget.po.poNumber,
                  styleId: widget.style.styleId,
                  styleName: widget.style.styleCode,
                  color: widget.style.color,
                  itemType: widget.style.itemType,
                  department: widget.department,
                  date: DateFormat('dd/MMMM/yy').format(DateTime.now()),
                );

                // Add hourly data to report
                for (var h in hourlyUpdates) {
                  report.hourlyData[h.hour] = h;
                }
                report.totalInput = totalInput;
                report.totalBalance = totalBalance;

                widget.onAdd(report);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Save Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary(List<HourlyUpdate> hourlyUpdates, String department) {
    if (hourlyUpdates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No data available.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    // Calculate daily totals
    int totalQcTarget = 0, totalQcAchieve = 0;
    int totalPolyTarget = 0, totalPolyAchieve = 0;
    int totalIronTarget = 0, totalIronAchieve = 0;
    int totalManpower = 0;
    Set<String> allBuyers = {};
    String style = '', color = '', item = '';

    for (var h in hourlyUpdates) {
      totalQcTarget += h.qcTarget;
      totalQcAchieve += h.qcAchieve;
      totalPolyTarget += h.polyTarget;
      totalPolyAchieve += h.polyAchieve;
      totalIronTarget += h.ironTarget;
      totalIronAchieve += h.ironAchieve;
      totalManpower += h.totalFinishingManpower;
      allBuyers.addAll(h.buyerNames);
      if (style.isEmpty && h.style.isNotEmpty) style = h.style;
      if (color.isEmpty && h.color.isNotEmpty) color = h.color;
      if (item.isEmpty && h.item.isNotEmpty) item = h.item;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Total - ${widget.department}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          // Buyer Names
          if (allBuyers.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Buyers: ${allBuyers.join(", ")}',
                          style: const TextStyle(fontSize: 11, color: Colors.blue),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          // Style, Color, Item
          if (style.isNotEmpty || color.isNotEmpty || item.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$style | $color | $item',
                          style: const TextStyle(fontSize: 11, color: Colors.purple),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          // Finishing Summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '✓ QC: $totalQcTarget/$totalQcAchieve',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '📦 Poly: $totalPolyTarget/$totalPolyAchieve',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🔩 Iron: $totalIronTarget/$totalIronAchieve',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (totalManpower > 0)
                      Text(
                        'Manpower: $totalManpower',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishingReportField(
    String label,
    int target,
    int achieve,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              Text(
                'Target: $target',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                'Achieve: $achieve',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== HOURLY UPDATE EDITOR ====================

class HourlyUpdateEditorDialog extends StatefulWidget {
  final HourlyUpdate hourlyUpdate;
  final String department;
  final Function onSave;

  const HourlyUpdateEditorDialog({
    super.key,
    required this.hourlyUpdate,
    required this.department,
    required this.onSave,
  });

  @override
  State<HourlyUpdateEditorDialog> createState() =>
      _HourlyUpdateEditorDialogState();
}

class _HourlyUpdateEditorDialogState extends State<HourlyUpdateEditorDialog> {
  late List<LineData> lines;
  Map<int, List<int>> unitLines = {}; // unit -> list of line numbers per unit

  @override
  void initState() {
    super.initState();
    lines = List.from(widget.hourlyUpdate.lines);
    _initializeStructure();
  }

  void _initializeStructure() {
    unitLines.clear();
    if (lines.isNotEmpty) {
      for (var line in lines) {
        if (!unitLines.containsKey(line.unitNumber)) {
          unitLines[line.unitNumber] = [];
        }
        unitLines[line.unitNumber]!.add(line.lineNumber);
      }
    } else {
      unitLines[1] = [1];
    }
  }

  void _addLineToUnit(int unit) {
    setState(() {
      if (!unitLines.containsKey(unit)) {
        unitLines[unit] = [];
      }
      // Get the next line number for this specific unit
      int nextLineForUnit = unitLines[unit]!.isEmpty
          ? 1
          : unitLines[unit]!.reduce((a, b) => a > b ? a : b) + 1;

      unitLines[unit]!.add(nextLineForUnit);
      lines.add(
        LineData(lineNumber: nextLineForUnit, unitNumber: unit, target: 0, department: widget.department),
      );
    });
  }

  void _removeLineFromUnit(int unit, int lineNumber) {
    setState(() {
      unitLines[unit]?.remove(lineNumber);
      lines.removeWhere(
        (l) => l.lineNumber == lineNumber && l.unitNumber == unit,
      );
      if (unitLines[unit]?.isEmpty ?? false) {
        unitLines.remove(unit);
      }
    });
  }

  void _addNewUnit() {
    setState(() {
      int newUnit = (unitLines.keys.isEmpty)
          ? 1
          : unitLines.keys.reduce((a, b) => a > b ? a : b) + 1;
      unitLines[newUnit] = [1];
      lines.add(LineData(lineNumber: 1, unitNumber: newUnit, target: 0, department: widget.department));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hour ${widget.hourlyUpdate.hour} - ${widget.department}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Achievement'),
                          Text(
                            '${lines.fold(0, (sum, l) => sum + l.achieve)} Pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.department != 'Cutting')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Units & Lines',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addNewUnit,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Unit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: widget.department != 'Cutting'
                        ? unitLines.entries.map((unitEntry) {
                            int unit = unitEntry.key;
                            List<int> lineNumbers = unitEntry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Unit $unit',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                            fontSize: 14,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _addLineToUnit(unit),
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('Add Line'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            textStyle:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...lineNumbers.map((lineNum) {
                                      var line = lines.firstWhere(
                                        (l) =>
                                            l.lineNumber == lineNum &&
                                            l.unitNumber == unit,
                                      );
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: _buildLineInputRow(unit, line),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            );
                          }).toList()
                        : lines.map((line) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildLineInputRow(0, line),
                            );
                          }).toList(),
                  ),
                ),
                ),
              // Fixed Buttons at Bottom
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Populate hourlyUpdate metadata from line inputs so reports can show them
                        widget.hourlyUpdate.lines = lines;
                        // style, color, item - take first non-empty from lines
                        final firstStyle = lines.firstWhere((l) => l.style.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).style;
                        final firstColor = lines.firstWhere((l) => l.color.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).color;
                        final firstItem = lines.firstWhere((l) => l.item.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).item;
                        widget.hourlyUpdate.style = firstStyle;
                        widget.hourlyUpdate.color = firstColor;
                        widget.hourlyUpdate.item = firstItem;
                        // buyers
                        widget.hourlyUpdate.buyerNames = lines.map((l) => l.buyerName).where((b) => b.isNotEmpty).toSet().toList();
                        widget.onSave();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    
    );
  }

  Widget _buildLineInputRow(int unit, LineData line) {
    // For Cutting department: show simplified fields
    // For Sewing/Finishing: show full fields with helpers
    
    if (widget.department == 'Cutting') {
      return _buildCuttingLineInput(unit, line);
    } else {
      return _buildSewingLineInput(unit, line);
    }
  }

  Widget _buildCuttingLineInput(int unit, LineData line) {
    final buyerController = TextEditingController(text: line.buyerName);
    final itemController = TextEditingController(text: line.item);
    final styleController = TextEditingController(text: line.style);
    final colorController = TextEditingController(text: line.color);
    final targetController = TextEditingController(
      text: line.target.toString(),
    );
    final dailyCuttingController = TextEditingController(
      text: line.achieve == 0 ? '' : line.achieve.toString(),
    );
    final dailyInputController = TextEditingController(
      text: line.dailyInput == 0 ? '' : line.dailyInput.toString(),
    );
    final totalInputController = TextEditingController(
      text: line.totalInput == 0 ? '' : line.totalInput.toString(),
    );
    final balanceController = TextEditingController(
      text: line.balance.toString(),
    );
    final operatorController = TextEditingController(text: line.operator);
    final shortOperatorController = TextEditingController(text: line.shortOperator);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line header with delete button (show style only)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              line.style.isNotEmpty
                  ? Text(
                      line.style,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    )
                  : const SizedBox.shrink(),
              IconButton(
                onPressed: () => _removeLineFromUnit(unit, line.lineNumber),
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Buyer / Factory field
          TextField(
            controller: buyerController,
            decoration: InputDecoration(
              labelText: 'Buyer / Factory',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.buyerName = val,
          ),
          const SizedBox(height: 8),
          // Item field
          TextField(
            controller: itemController,
            decoration: InputDecoration(
              labelText: 'Item',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.item = val,
          ),
          const SizedBox(height: 8),
          // Style field
          TextField(
            controller: styleController,
            decoration: InputDecoration(
              labelText: 'Style',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.style = val,
          ),
          const SizedBox(height: 8),
          // Color field
          TextField(
            controller: colorController,
            decoration: InputDecoration(
              labelText: 'Color',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.color = val,
          ),
          const SizedBox(height: 8),
          // Target field
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.target = int.tryParse(val) ?? line.target,
          ),
          const SizedBox(height: 8),
          // Daily Cutting field
          TextField(
            controller: dailyCuttingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Cutting',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.achieve = int.tryParse(val) ?? line.achieve,
          ),
          const SizedBox(height: 8),
          // Daily Input field
          TextField(
            controller: dailyInputController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.dailyInput = int.tryParse(val) ?? line.dailyInput,
          ),
          const SizedBox(height: 8),
          // Total Input field
          TextField(
            controller: totalInputController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.totalInput = int.tryParse(val) ?? line.totalInput,
          ),
          const SizedBox(height: 8),
          // Balance field
          TextField(
            controller: balanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Balance',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.balance = int.tryParse(val) ?? line.balance,
          ),
          const SizedBox(height: 8),
          // Operator field
          TextField(
            controller: operatorController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.operator = val,
          ),
          const SizedBox(height: 8),
          // Short Operator field
          TextField(
            controller: shortOperatorController,
                        keyboardType: TextInputType.number,

            decoration: InputDecoration(
              labelText: 'Short Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortOperator = val,
          ),
        ],
      ),
    );
  }

  Widget _buildSewingLineInput(int unit, LineData line) {
    String? selectedBuyer = line.buyerName.isNotEmpty ? line.buyerName : null;
    String? selectedStyle = line.style.isNotEmpty ? line.style : null;
    String? selectedItem = line.item.isNotEmpty ? line.item : null;
    String? selectedColor = line.color.isNotEmpty ? line.color : null;

    final buyerOptions = ['Winner Jeans', 'Dreamtex', 'Fashion Fast'];
    final itemOptions = ['T-Shirt', 'Pant', 'Shirt'];
    final styleOptions = ['Style A', 'Style B', 'Style C'];
    final colorOptions = ['Red', 'Blue', 'Black'];

    final targetController = TextEditingController(
      text: line.target > 0 ? line.target.toString() : '',
    );
    final achieveController = TextEditingController(
      text: line.achieve == 0 ? '' : line.achieve.toString(),
    );
    final balanceController = TextEditingController(
      text: line.balance.toString(),
    );
    final operatorController = TextEditingController(text: line.operator);
    final shortOperatorController = TextEditingController(text: line.shortOperator);
    final helperController = TextEditingController(text: line.helper);
    final shortHelperController = TextEditingController(text: line.shortHelper);
    final bartechOperatorController = TextEditingController(text: line.bartechOperator);
    final bartechHelperController = TextEditingController(text: line.bartechHelper);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line header with delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line ${line.lineNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue,
                ),
              ),
              IconButton(
                onPressed: () => _removeLineFromUnit(unit, line.lineNumber),
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Buyer field (dropdown)
          DropdownButtonFormField<String>(
            value: selectedBuyer,
            items: buyerOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.buyerName = val; },
            decoration: InputDecoration(hintText: 'Buyer / Factory', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          // Style field (dropdown)
          DropdownButtonFormField<String>(
            value: selectedStyle,
            items: styleOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.style = val; },
            decoration: InputDecoration(labelText: 'Style', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          // Item field (dropdown)
          DropdownButtonFormField<String>(
            value: selectedItem,
            items: itemOptions.map((it) => DropdownMenuItem(value: it, child: Text(it, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.item = val; },
            decoration: InputDecoration(labelText: 'Item', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          // Color field (dropdown)
          DropdownButtonFormField<String>(
            value: selectedColor,
            items: colorOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.color = val; },
            decoration: InputDecoration(labelText: 'Color', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          // Target field
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target',
              hintText: 'Enter target',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.target = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 8),
          // Daily Input field
          TextField(
            controller: achieveController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.achieve = int.tryParse(val) ?? line.achieve,
          ),
          const SizedBox(height: 8),
          // Total Input field (Display only - auto calculated)
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Total Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            style: const TextStyle(fontSize: 11),
            controller: TextEditingController(text: line.achieve == 0 ? '' : line.achieve.toString()),
          ),
          const SizedBox(height: 8),
          // Balance field
          TextField(
            controller: balanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Balance',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.balance = int.tryParse(val) ?? line.balance,
          ),
          const SizedBox(height: 8),
          // Operator field
          TextField(
            controller: operatorController,
            decoration: InputDecoration(
              labelText: 'Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.operator = val,
          ),
          const SizedBox(height: 8),
          // Short Operator field
          TextField(
            controller: shortOperatorController,
            decoration: InputDecoration(
              labelText: 'Short Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortOperator = val,
          ),
          const SizedBox(height: 8),
          // Helper field
          TextField(
            controller: helperController,
            decoration: InputDecoration(
              labelText: 'Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.helper = val,
          ),
          const SizedBox(height: 8),
          // Short Helper field
          TextField(
            controller: shortHelperController,
            decoration: InputDecoration(
              labelText: 'Short Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortHelper = val,
          ),
          const SizedBox(height: 8),
          // Bartech Operator field
          TextField(
            controller: bartechOperatorController,
            decoration: InputDecoration(
              labelText: 'Bartech Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.bartechOperator = val,
          ),
          const SizedBox(height: 8),
          // Bartech Helper field
          TextField(
            controller: bartechHelperController,
            decoration: InputDecoration(
              labelText: 'Bartech Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.bartechHelper = val,
          ),
        ],
      ),
    );
  }
}

// ==================== HOURLY INPUT PAGE ====================

class HourlyInputPage extends StatefulWidget {
  final HourlyUpdate hourlyUpdate;
  final String department;
  final Function onSave;
  final PurchaseOrder? po;
  final StyleItem? style;
  final Function(PurchaseOrder, StyleItem, String, List<HourlyUpdate>)? onShowSummary;

  const HourlyInputPage({
    super.key,
    required this.hourlyUpdate,
    required this.department,
    required this.onSave,
    this.po,
    this.style,
    this.onShowSummary,
  });

  @override
  State<HourlyInputPage> createState() => _HourlyInputPageState();
}

class _HourlyInputPageState extends State<HourlyInputPage> {
  late List<LineData> lines;
  Map<int, List<int>> unitLines = {}; // unit -> list of line numbers per unit

  @override
  void initState() {
    super.initState();
    lines = List.from(widget.hourlyUpdate.lines);
    _initializeStructure();
  }

  void _initializeStructure() {
    unitLines.clear();
    if (lines.isNotEmpty) {
      for (var line in lines) {
        if (!unitLines.containsKey(line.unitNumber)) {
          unitLines[line.unitNumber] = [];
        }
        unitLines[line.unitNumber]!.add(line.lineNumber);
      }
    } else {
      unitLines[1] = [1];
    }
  }

  void _syncToOrderManager(List<LineData> lines) {
    // Sync admin's input to OrderManager for Supervisor to see
    try {
      final orders = orderManager.getAllOrders();
      if (orders.isNotEmpty) {
        final order = orders[0]; // Primary order
        
        // Remove existing lines for this department, keep other departments' lines
        order.lines.removeWhere((l) => l.department == widget.department);

        for (var line in lines) {
          // Only add lines that have meaningful data
          if (line.buyerName.isNotEmpty || line.style.isNotEmpty) {
            final orderLine = OrderLineData(
              buyerName: line.buyerName,
              style: line.style,
              item: line.item,
              color: line.color,
              target: line.target,
              operator: line.operator,
              shortOperator: line.shortOperator,
              bartechOperator: line.bartechOperator,
              bartechHelper: line.bartechHelper,
              unitNumber: line.unitNumber,
              lineNumber: line.lineNumber,
              // Map based on department to prevent field swapping:
              // Cutting stores achieve in dailyCutting field
              // Sewing stores achieve in achieve field
              dailyCutting: widget.department == 'Cutting' ? line.achieve : 0,
              dailyInput: line.dailyInput,
              department: widget.department, // Pass department info
              achieve: widget.department == 'Sewing' ? line.achieve : 0,
              qcTarget: 0,
              polyTarget: 0,
              ironTarget: 0,
            );
            order.lines.add(orderLine);
          }
        }
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }

  void _addLineToUnit(int unit) {
    setState(() {
      if (!unitLines.containsKey(unit)) {
        unitLines[unit] = [];
      }
      int nextLineForUnit = unitLines[unit]!.isEmpty
          ? 1
          : unitLines[unit]!.reduce((a, b) => a > b ? a : b) + 1;

      unitLines[unit]!.add(nextLineForUnit);
      lines.add(
        LineData(lineNumber: nextLineForUnit, unitNumber: unit, target: 0, department: widget.department),
      );
    });
  }

  void _removeLineFromUnit(int unit, int lineNumber) {
    setState(() {
      unitLines[unit]?.remove(lineNumber);
      lines.removeWhere(
        (l) => l.lineNumber == lineNumber && l.unitNumber == unit,
      );
      if (unitLines[unit]?.isEmpty ?? false) {
        unitLines.remove(unit);
      }
    });
  }

  void _addNewUnit() {
    setState(() {
      int newUnit = (unitLines.keys.isEmpty)
          ? 1
          : unitLines.keys.reduce((a, b) => a > b ? a : b) + 1;
      unitLines[newUnit] = [1];
      lines.add(LineData(lineNumber: 1, unitNumber: newUnit, target: 0, department: widget.department));
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalAchieve = lines.fold(0, (sum, l) => sum + l.achieve);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: Text('Hour ${widget.hourlyUpdate.hour} - ${widget.department}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            // Header with total achievement
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Achievement',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalAchieve Pcs',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.department != 'Cutting') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Units & Lines',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addNewUnit,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Unit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...unitLines.entries.map((unitEntry) {
                        int unit = unitEntry.key;
                        List<int> lineNumbers = unitEntry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Unit $unit',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        fontSize: 14,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _addLineToUnit(unit),
                                      icon: const Icon(Icons.add, size: 14),
                                      label: const Text('Add Line'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...lineNumbers.map((lineNum) {
                                  var line = lines.firstWhere(
                                    (l) =>
                                        l.lineNumber == lineNum &&
                                        l.unitNumber == unit,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child:
                                        _buildLineInputRow(unit, line, lineNum),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ] else ...[
                      // Cutting: don't show unit/line headers — render flat line inputs
                      ...lines.map((line) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildLineInputRow(0, line, line.lineNumber),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                    ElevatedButton(
                      onPressed: () {
                      // Populate hourlyUpdate metadata from line inputs so reports can show them
                      widget.hourlyUpdate.lines = lines;
                      final firstStyle = lines.firstWhere((l) => l.style.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).style;
                      final firstColor = lines.firstWhere((l) => l.color.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).color;
                      final firstItem = lines.firstWhere((l) => l.item.isNotEmpty, orElse: () => LineData(lineNumber: 0, unitNumber: 0, target: 0)).item;
                      widget.hourlyUpdate.style = firstStyle;
                      widget.hourlyUpdate.color = firstColor;
                      widget.hourlyUpdate.item = firstItem;
                      widget.hourlyUpdate.buyerNames = lines.map((l) => l.buyerName).where((b) => b.isNotEmpty).toSet().toList();
                      
                      // Sync to OrderManager for Supervisor to see
                      _syncToOrderManager(lines);
                      
                      widget.onSave();
                      
                      // Show Summary dialog if po, style, and callback provided
                      if (widget.po != null && widget.style != null && widget.onShowSummary != null) {
                        final allHourlyUpdates = widget.style!.departmentHourlyUpdates[widget.department] ?? [];
                        widget.onShowSummary!(widget.po!, widget.style!, widget.department, allHourlyUpdates);
                        Navigator.pop(context);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineInputRow(int unit, LineData line, int lineNum) {
    if (widget.department == 'Cutting') {
      return _buildCuttingLineInputRow(unit, line, lineNum);
    } else {
      return _buildSewingLineInputRow(unit, line, lineNum);
    }
  }

  Widget _buildCuttingLineInputRow(int unit, LineData line, int lineNum) {
    String? selectedBuyer = line.buyerName.isNotEmpty ? line.buyerName : null;
    String? selectedItem = line.item.isNotEmpty ? line.item : null;
    String? selectedStyle = line.style.isNotEmpty ? line.style : null;
    String? selectedColor = line.color.isNotEmpty ? line.color : null;

    final buyerOptions = ['Winner Jeans', 'Dreamtex', 'Fashion Fast'];
    final itemOptions = ['T-Shirt', 'Pant', 'Shirt'];
    final styleOptions = ['Style A', 'Style B', 'Style C'];
    final colorOptions = ['Red', 'Blue', 'Black'];

    final targetController = TextEditingController(
      text: line.target > 0 ? line.target.toString() : '',
    );
    final achieveController = TextEditingController(
      text: line.achieve == 0 ? '' : line.achieve.toString(),
    );
    final dailyInputController = TextEditingController(
      text: line.dailyInput == 0 ? '' : line.dailyInput.toString(),
    );
    final totalInputController = TextEditingController(
      text: line.totalInput == 0 ? '' : line.totalInput.toString(),
    );
    final balanceController = TextEditingController(
      text: line.balance.toString(),
    );
    final operatorController = TextEditingController(text: line.operator);
    final shortOperatorController = TextEditingController(
      text: line.shortOperator,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              line.style.isNotEmpty
                  ? Text(
                      line.style,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    )
                  : const SizedBox.shrink(),
              IconButton(
                onPressed: () => _removeLineFromUnit(unit, lineNum),
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedBuyer,
            items: buyerOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.buyerName = val; },
            decoration: InputDecoration(labelText: 'Buyer / Factory', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedItem,
            items: itemOptions.map((it) => DropdownMenuItem(value: it, child: Text(it, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.item = val; },
            decoration: InputDecoration(labelText: 'Item', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedStyle,
            items: styleOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.style = val; },
            decoration: InputDecoration(labelText: 'Style', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedColor,
            items: colorOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.color = val; },
            decoration: InputDecoration(labelText: 'Color', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target',
              hintText: 'Enter target',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.target = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: achieveController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Cutting',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.achieve = int.tryParse(val) ?? line.achieve,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: dailyInputController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.dailyInput = int.tryParse(val) ?? line.dailyInput,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: totalInputController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Total Input',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.totalInput = int.tryParse(val) ?? line.totalInput,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: balanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Balance',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.balance = int.tryParse(val) ?? line.balance,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: operatorController,
            decoration: InputDecoration(
              labelText: 'Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.operator = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: shortOperatorController,
            decoration: InputDecoration(
              labelText: 'Short Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortOperator = val,
          ),
        ],
      ),
    );
  }

  Widget _buildSewingLineInputRow(int unit, LineData line, int lineNum) {
    String? selectedBuyer = line.buyerName.isNotEmpty ? line.buyerName : null;
    String? selectedStyle = line.style.isNotEmpty ? line.style : null;
    String? selectedItem = line.item.isNotEmpty ? line.item : null;
    String? selectedColor = line.color.isNotEmpty ? line.color : null;

    final buyerOptions = ['Winner Jeans', 'Dreamtex', 'Fashion Fast'];
    final itemOptions = ['T-Shirt', 'Pant', 'Shirt'];
    final styleOptions = ['Style A', 'Style B', 'Style C'];
    final colorOptions = ['Red', 'Blue', 'Black'];

    final targetController = TextEditingController(
      text: line.target > 0 ? line.target.toString() : '',
    );
    final achieveController = TextEditingController(
      text: line.achieve == 0 ? '' : line.achieve.toString(),
    );
    final balanceController = TextEditingController(
      text: line.balance.toString(),
    );
    final operatorController = TextEditingController(text: line.operator);
    final shortOperatorController = TextEditingController(
      text: line.shortOperator,
    );
    final helperController = TextEditingController(text: line.helper);
    final shortHelperController = TextEditingController(text: line.shortHelper);
    final bartechOperatorController = TextEditingController(text: line.bartechOperator);
    final bartechHelperController = TextEditingController(text: line.bartechHelper);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line $lineNum',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue,
                ),
              ),
              IconButton(
                onPressed: () => _removeLineFromUnit(unit, lineNum),
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedBuyer,
            items: buyerOptions.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.buyerName = val; },
            decoration: InputDecoration(labelText: 'Buyer / Factory', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedStyle,
            items: styleOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.style = val; },
            decoration: InputDecoration(labelText: 'Style', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedItem,
            items: itemOptions.map((it) => DropdownMenuItem(value: it, child: Text(it, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.item = val; },
            decoration: InputDecoration(labelText: 'Item', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedColor,
            items: colorOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11)))) .toList(),
            onChanged: (val) { if (val != null) line.color = val; },
            decoration: InputDecoration(labelText: 'Color', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target',
              hintText: 'Enter target',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.target = int.tryParse(val) ?? 0,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: achieveController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Achieve',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.achieve = int.tryParse(val) ?? line.achieve,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: balanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Balance',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) =>
                line.balance = int.tryParse(val) ?? line.balance,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: operatorController,
            decoration: InputDecoration(
              labelText: 'Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.operator = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: shortOperatorController,
            decoration: InputDecoration(
              labelText: 'Short Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortOperator = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: helperController,
            decoration: InputDecoration(
              labelText: 'Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.helper = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: shortHelperController,
            decoration: InputDecoration(
              labelText: 'Short Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.shortHelper = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bartechOperatorController,
            decoration: InputDecoration(
              labelText: 'Bartech Operator',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.bartechOperator = val,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: bartechHelperController,
            decoration: InputDecoration(
              labelText: 'Bartech Helper',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 11),
            onChanged: (val) => line.bartechHelper = val,
          ),
        ],
      ),
    );
  }
}

// Helper extension
extension GroupBy<K, V> on List<V> {
  Map<K, List<V>> groupBy<K>(K Function(V) keyFn) {
    final map = <K, List<V>>{};
    for (final item in this) {
      final key = keyFn(item);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

