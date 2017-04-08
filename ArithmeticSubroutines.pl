# 2017/03/06
# �N�H�[�^�j�I����s��v�Z�̃T�u���[�`��

use strict;

# �s�񉉎Z�̂��߂ɁA���W���[��MatrixReal���g�p���Ă��܂��B
# �C���X�g�[�����@�ɂ��ĊȒP�ɐ������Ă�����H
# �y�Q�l�z
# ���{��
# http://www001.upp.so-net.ne.jp/hata/dowasure_perl.html#matrix
# �����}�j���A��
# http://search.cpan.org/~leto/Math-MatrixReal-2.13/lib/Math/MatrixReal.pm
use Math::MatrixReal;

# �x�N�g�����Z�̂��߂̃��W���[��
# http://www.mahoroba.ne.jp/~felix/Toolbox/Lang/Perl/Package/Math-Vector.html
use Math::Vector;

# �O�p�֐����g�����߂̃��W���[��
use Math::Trig;

# �p�b�P�[�W���̒�`
# package ArithmeticSubroutines;
# ���p�b�P�[�W��錾���Ȃ���΁A���C���\�[�X�ŃT�u���[�`�����Ăяo�����ɂ��������h���C���i?�j��錾�����ɍςށB

###################### �T�u���[�`���̒�` ######################

# �x�N�g�����畽�s�ړ��s��𐶐�
# �ϊ��s�� T =
#  | 1 0 0 x |
#  | 0 1 0 y |
#  | 0 0 1 z |
#  | 0 0 0 1 |
sub MGetTranslate
{
	my ($vx, $vy, $vz) = @_;
	
	# 4x4�P�ʍs��𐶐�
	my $MTrans =  Math::MatrixReal->new_diag( [ 1,1,1,1 ] );
	
	# 4��ڂ𕽍s�ړ������ɏ�������
	$MTrans->assign(1,4,$vx);
	$MTrans->assign(2,4,$vy);
	$MTrans->assign(3,4,$vz);
	
	return $MTrans;

}

# �N�I�[�^�j�I�������]�s��(4x4)�𓾂�
# http://miffysora.wikidot.com/quaternion:matrix
# ��]�s�� R =
#  | 1-2(yy+zz)   2(xy-zw)   2(zx+yw)  0 |
#  |   2(xy+zw) 1-2(zz+xx)   2(yz-xw)  0 |
#  |   2(zx-yw)   2(yz+xw) 1-2(xx+yy)  0 |
#  |          0          0          0  1 |
sub MGetRotQuaternion
{
	my ($x, $y, $z, $w) = @_;

	my @array_work =
	 ( [ 1-2*($y*$y+$z*$z),   2*($x*$y-$z*$w),   2*($z*$x+$y*$w),  0 ],
	   [   2*($x*$y+$z*$w), 1-2*($z*$z+$x*$x),   2*($y*$z-$x*$w),  0 ],
	   [   2*($z*$x-$y*$w),   2*($y*$z+$x*$w), 1-2*($x*$x+$y*$y),  0 ],
	   [                 0,                 0,                 0,  1 ] );

	my $MRot = Math::MatrixReal->new_from_rows(\@array_work);
	
	return $MRot;

}

# �Q�̃N�I�[�^�j�I������������
# QuatMult( @Q1, @Q2 )  ���N�I�[�^�j�I���͎Q�Ɠn���ł͂Ȃ�
# Q1 = ( $x, $y, $z, $w )
sub QuatMult
{
	my ( $x1, $y1, $z1, $w1, $x2, $y2, $z2, $w2 ) = @_;
	
	my @V1 = ( $x1, $y1, $z1 );
	my @V2 = ( $x2, $y2, $z2 );

	my $v = Math::Vector->new();
	my $w = $w1*$w2 - $v->DotProduct(@V1, @V2);
	
	my @tmp1 = $v->ScalarMult($w1,@V2);
	my @tmp2 = $v->ScalarMult($w2,@V1);
	my @tmp3 = $v->CrossProduct(@V1, @V2);
	my @V = $v->VecAdd(@tmp1,@tmp2,@tmp3);
	
	return ( @V, $w );
	
	# ���[�A���Ƃ͓���m�F���΁B

}

# ��]���Ɖ�]�p����N�I�[�^�j�I���̐���
# �����F�i $��]�p, @��]���̃x�N�g�� �j
# �߂�l�F�N�H�[�^�j�I�� ( $x, $y, $z, $w )
sub QuatRotation
{
	my ( $RotQuant, @RotAxis ) = @_;
	
	my $v = Math::Vector->new();
	
	my $sinharf = sin( 0.5 * $RotQuant );
	my $cosharf = cos( 0.5 * $RotQuant );
	
	my @Qvec = $v->ScalarMult( $sinharf, @RotAxis );
	
	# �E��n������n�֕ϊ�����
	#$Qvec[2] *= -1;
	#$cosharf *= -1;
	
	return ( @Qvec, $cosharf );

}

# �^����ꂽ�N�H�[�^�j�I������A��]���̃x�N�g���ƁA��]�p���v�Z����B
# ����  �F�����������N�H�[�^�j�I�� Q = ( $x, $y, $z, $w )
# �߂�l�F�i $��]�p, @��]���̃x�N�g�� �j
sub QuatRestore
{
	my ( $x1, $y1, $z1, $w1 ) = @_;
	
	# ����n���E��n�֕ϊ�����
	#$z1 *= -1;
	#$w1 *= -1;

	my $v = Math::Vector->new();

	# cos( Theta / 2 )
	my $cosharf = $w1;
	
	# sin( Theta / 2 )
	my $sinharf = $v->Magnitude( $x1, $y1, $z1 );
	
	# ��]���̃x�N�g��
	my @RotAxis =  $v->ScalarMult( (1/$sinharf), $x1, $y1, $z1 );
	
	# print $sinharf, ",", $cosharf, "\n";
	
	# ��]�p�̌v�Z
	my $RotQuant = 2 * atan2( $sinharf, $cosharf );
	
	return ( $RotQuant, @RotAxis );

}

# �T�u���[�`���̍Ō�ɁA�u1;�v��K�������B
# http://d.hatena.ne.jp/midori_kasugano/20100312/1268382079
1;





