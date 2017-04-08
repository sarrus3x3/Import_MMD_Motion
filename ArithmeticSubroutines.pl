# 2017/03/06
# クォータニオンや行列計算のサブルーチン

use strict;

# 行列演算のために、モジュールMatrixRealを使用しています。
# インストール方法について簡単に説明してあげる？
# 【参考】
# 日本語
# http://www001.upp.so-net.ne.jp/hata/dowasure_perl.html#matrix
# 公式マニュアル
# http://search.cpan.org/~leto/Math-MatrixReal-2.13/lib/Math/MatrixReal.pm
use Math::MatrixReal;

# ベクトル演算のためのモジュール
# http://www.mahoroba.ne.jp/~felix/Toolbox/Lang/Perl/Package/Math-Vector.html
use Math::Vector;

# 三角関数を使うためのモジュール
use Math::Trig;

# パッケージ名の定義
# package ArithmeticSubroutines;
# ↑パッケージを宣言しなければ、メインソースでサブルーチンを呼び出す時にいちいちドメイン（?）を宣言せずに済む。

###################### サブルーチンの定義 ######################

# ベクトルから平行移動行列を生成
# 変換行列 T =
#  | 1 0 0 x |
#  | 0 1 0 y |
#  | 0 0 1 z |
#  | 0 0 0 1 |
sub MGetTranslate
{
	my ($vx, $vy, $vz) = @_;
	
	# 4x4単位行列を生成
	my $MTrans =  Math::MatrixReal->new_diag( [ 1,1,1,1 ] );
	
	# 4列目を平行移動成分に書き換え
	$MTrans->assign(1,4,$vx);
	$MTrans->assign(2,4,$vy);
	$MTrans->assign(3,4,$vz);
	
	return $MTrans;

}

# クオータニオンから回転行列(4x4)を得る
# http://miffysora.wikidot.com/quaternion:matrix
# 回転行列 R =
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

# ２つのクオータニオンを合成する
# QuatMult( @Q1, @Q2 )  ※クオータニオンは参照渡しではない
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
	
	# さー、あとは動作確認をば。

}

# 回転軸と回転角からクオータニオンの生成
# 引数：（ $回転角, @回転軸のベクトル ）
# 戻り値：クォータニオン ( $x, $y, $z, $w )
sub QuatRotation
{
	my ( $RotQuant, @RotAxis ) = @_;
	
	my $v = Math::Vector->new();
	
	my $sinharf = sin( 0.5 * $RotQuant );
	my $cosharf = cos( 0.5 * $RotQuant );
	
	my @Qvec = $v->ScalarMult( $sinharf, @RotAxis );
	
	# 右手系→左手系へ変換する
	#$Qvec[2] *= -1;
	#$cosharf *= -1;
	
	return ( @Qvec, $cosharf );

}

# 与えられたクォータニオンから、回転軸のベクトルと、回転角を計算する。
# 引数  ：復元したいクォータニオン Q = ( $x, $y, $z, $w )
# 戻り値：（ $回転角, @回転軸のベクトル ）
sub QuatRestore
{
	my ( $x1, $y1, $z1, $w1 ) = @_;
	
	# 左手系→右手系へ変換する
	#$z1 *= -1;
	#$w1 *= -1;

	my $v = Math::Vector->new();

	# cos( Theta / 2 )
	my $cosharf = $w1;
	
	# sin( Theta / 2 )
	my $sinharf = $v->Magnitude( $x1, $y1, $z1 );
	
	# 回転軸のベクトル
	my @RotAxis =  $v->ScalarMult( (1/$sinharf), $x1, $y1, $z1 );
	
	# print $sinharf, ",", $cosharf, "\n";
	
	# 回転角の計算
	my $RotQuant = 2 * atan2( $sinharf, $cosharf );
	
	return ( $RotQuant, @RotAxis );

}

# サブルーチンの最後に、「1;」を必ず入れる。
# http://d.hatena.ne.jp/midori_kasugano/20100312/1268382079
1;





