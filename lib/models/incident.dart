class Incident {
  // ...
  // Remove the department field
  // final String department;

  Incident({
    // ...
    // Remove the department parameter
    // this.department,
  });

  // Remove the department from the toJson method
  Map<String, dynamic> toJson() {
    return {
      // ...
      // Remove the department field
      // 'department': department,
    };
  }

  // Remove the department from the fromJson factory
  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      // ...
      // Remove the department field
      // department: json['department'] ?? '',
    );
  }
} 