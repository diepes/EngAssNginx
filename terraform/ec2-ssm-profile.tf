resource "aws_iam_instance_profile" "ssm-profile" {
  name = "AmazonSSMManagedInstanceCore"
  role = aws_iam_role.AmazonSSMManaged.name
}

resource "aws_iam_role" "AmazonSSMManaged" {
  name = "AmazonSSMManagedInstance"
  #path = "/"
  assume_role_policy = data.aws_iam_policy_document.ssm-ec2.json
}

data "aws_iam_policy_document" "ssm-ec2" {
  statement {
      principals  {
          type = "Service"
          identifiers = [ "ec2.amazonaws.com", ]
      }
      actions = [ "sts:AssumeRole", ]
  }
}

resource "aws_iam_role_policy_attachment" "SSM" {
  role       = aws_iam_role.AmazonSSMManaged.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}