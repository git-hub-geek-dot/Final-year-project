String paymentRateTypeLabel(dynamic rateType) {
  switch (rateType?.toString().toLowerCase()) {
    case "per_hour":
      return "per hour";
    case "fixed":
      return "fixed amount";
    case "per_day":
    default:
      return "per day";
  }
}

String? formatPaidPaymentAmount(dynamic amount, dynamic rateType) {
  final amountText = amount?.toString();
  if (amountText == null || amountText.isEmpty) {
    return null;
  }

  final rateLabel = paymentRateTypeLabel(rateType);
  if (rateLabel == "fixed amount") {
    return "Rs. $amountText fixed amount";
  }

  return "Rs. $amountText $rateLabel";
}

String formatEventPaymentText(
  dynamic eventType,
  dynamic paymentAmount,
  dynamic paymentRateType,
) {
  final type = eventType?.toString().toLowerCase();
  if (type != "paid") {
    return "Unpaid";
  }

  final paymentText = formatPaidPaymentAmount(paymentAmount, paymentRateType);
  if (paymentText == null) {
    return "Paid";
  }

  return "Paid: $paymentText";
}
