Future<void> saveIncident(Incident incident) async {
  // ...
  final incidentData = incident.toJson();
  // Remove the department field from the document
  // incidentData.remove('department');
  // ...
} 