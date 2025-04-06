class ServiceInfo {
  final String serviceType;
  final String orgName;
  final String hotlineNumber;
  final int? id;

  ServiceInfo(this.serviceType,
      {required this.orgName, required this.hotlineNumber, this.id});
}
