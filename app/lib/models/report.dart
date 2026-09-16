/// Why someone is being reported (B33). The ids are what the rules accept;
/// report_test checks the two lists match.
enum ReportReason {
  harassment('harassment', '嫌がらせ・脅迫・つきまとい'),
  locating('locating', '場所を探られる・会うことを強要される'),
  inappropriate('inappropriate', 'わいせつ・暴力的・差別的な内容'),
  spam('spam', '宣伝・勧誘・出会い目的'),
  other('other', 'その他');

  const ReportReason(this.id, this.label);

  final String id;
  final String label;
}

/// A report's free-text detail is optional, and capped like a letter.
const maxReportDetailLength = 1000;
