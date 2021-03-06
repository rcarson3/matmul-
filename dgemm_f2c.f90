!
! Illustrate a Fortran 2003 style C-Fortran interface
! It has been more than a decade since the standard --
! most compilers should support it at this point.
!
subroutine do_blockL2(lda, A, B, C, i, j, k, BLOCK_SIZEL2, Asmall, Bsmall, Csmall, BLOCK_SIZEL1)
    implicit none

    integer, intent(in) :: lda, i, j, k, BLOCK_SIZEL2, BLOCK_SIZEL1
    real*8, intent (in) :: A(0:lda-1, 0:lda-1)
    real*8, intent (in) :: B(0:lda-1, 0:lda-1)
    real*8, intent (inout) :: C(0:lda-1, 0:lda-1)

    real*8, intent(inout) :: Asmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8, intent(inout) :: Bsmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8, intent(inout) :: Csmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)

    integer :: M, N, Kbig, MM, NN, KK, n_blocks1, i1, j1, k1
    integer :: bj, bk, bi

    ! inner number of blocks based upon number of small blocks that can fit into the large block

    n_blocks1 = BLOCK_SIZEL2 / BLOCK_SIZEL1 + merge(1, 0, mod(BLOCK_SIZEL2,BLOCK_SIZEL1).gt.0)

    !An exact copy of the outer blocking scheme

    do bj = 0, n_blocks1-1
        j1 = bj * BLOCK_SIZEL1
        do bk = 0, n_blocks1-1
            k1 = bk * BLOCK_SIZEL1
            do bi = 0, n_blocks1-1
                i1 = bi * BLOCK_SIZEL1
!                write(*,*) 'got here'
                call do_blockL1(lda, A, B, C, i, j, k, i1, j1, k1, BLOCK_SIZEL1, Asmall, Bsmall, Csmall)
!                write(*,*) 'got here'
            end do
        end do
    end do

end subroutine do_blockL2

subroutine do_blockL1(lda, A, B, C, i, j, k, i1, j1, k1, BLOCK_SIZEL1, Asmall, Bsmall, Csmall)
    implicit none

    integer, intent(in) :: lda, i, j, k, i1, j1, k1, BLOCK_SIZEL1
    real*8, intent (in) :: A(0:lda-1, 0:lda-1)
    real*8, intent (in) :: B(0:lda-1, 0:lda-1)
    real*8, intent (inout) :: C(0:lda-1, 0:lda-1)
!
    real*8, intent(inout) :: Asmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8, intent(inout) :: Bsmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8, intent(inout) :: Csmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)

    integer :: M, N, Kbig, MM, NN, KK

    !check to see if the 2 block scheme ends up outside the allowable matrix dimensions

    if ((i+i1).ge.lda .or. (j+j1).ge.lda .or. (k+k1) .ge. lda) then
       return
    else

        !Get end location of matrices

        M = i+i1+merge(lda-(i+i1), BLOCK_SIZEL1, (i+i1+BLOCK_SIZEL1) .gt. lda)
        N = j+j1+merge(lda-(j+j1), BLOCK_SIZEL1, (j+j1+BLOCK_SIZEL1) .gt. lda)
        Kbig = k+k1+merge(lda-(k+k1), BLOCK_SIZEL1, (k+k1+BLOCK_SIZEL1) .gt. lda)

        ! Performing a tertiary operation to get appropriate dimensions of the matrix

        MM = merge(mod(M, BLOCK_SIZEL1), BLOCK_SIZEL1, mod(M, BLOCK_SIZEL1) .gt. 0)
        NN = merge(mod(N, BLOCK_SIZEL1), BLOCK_SIZEL1, mod(N, BLOCK_SIZEL1) .gt. 0)
        KK = merge(mod(Kbig, BLOCK_SIZEL1), BLOCK_SIZEL1, mod(Kbig, BLOCK_SIZEL1) .gt. 0)

        ! Pad matrix with zeros

        Asmall = 0.0
        Bsmall = 0.0
        Csmall = 0.0

        !Doing the copy optimization for better memory locality

        Asmall(0:MM-1, 0:KK-1) = A((i+i1):M-1, (k+k1):Kbig-1)
        Bsmall(0:KK-1, 0:NN-1) = B((k+k1):Kbig-1, (j+j1):N-1)
        Csmall(0:MM-1, 0:NN-1) = C((i+i1):M-1, (j+j1):N-1)

        call dgemm(Asmall, BLOCK_SIZEL1, BLOCK_SIZEL1, Bsmall, BLOCK_SIZEL1, BLOCK_SIZEL1, Csmall, BLOCK_SIZEL1, BLOCK_SIZEL1)

        C((i+i1):M-1, (j+j1):N-1) = Csmall(0:MM-1, 0:NN-1)


    endif

end subroutine do_blockL1

SUBROUTINE DGEMM(A,lda,lta,B,ldb,ltb,C,ldc,ltc)

IMPLICIT NONE

INTEGER, INTENT(IN) :: lda, lta, ldb, ltb, ldc, ltc

REAL*8 , INTENT(IN) :: a(1:lda, 1:lta), b(1:ldb, 1:ltb)
REAL*8 , INTENT(INOUT):: c(1:ldc, 1:ltc)


INTEGER :: j, k

!
!------------------------------------------------------------------

! simple matrix-matrix multiplication taking advantage of Fortran's natural ability to vectorize
! moved into this file to ensure the compiler vectorizes it with the AVX2 instruction sets

do k = 1,ltb
    do j = 1,lta
          c(:, k) = c(:, k) + a(:, j)*b(j, k)
    end do
end do

END SUBROUTINE DGEMM

subroutine square_dgemm(M, A, B, C) bind(C)

    use, intrinsic :: iso_c_binding
    implicit none

    integer (c_int), value :: M
    ! L2 cache size
    integer, parameter :: BLOCK_SIZEL2 = 96
    real (c_double), intent (inout), dimension(*) :: A
    real (c_double), intent (inout), dimension(*) :: B
    real (c_double), intent (inout), dimension(*) :: C

    ! L1 cache size
    integer, parameter :: BLOCK_SIZEL1 = 32

    ! reducing number of times the copy matrices are created by moving them to the top function
    ! would be better to put this all in a module though and then just have them sit at the global
    ! module level instead

    real*8 :: Asmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8 :: Bsmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
    real*8 :: Csmall(0:BLOCK_SIZEL1-1, 0:BLOCK_SIZEL1-1)
        !giving the compiler directives that the copy matrices are aligned with a 32-byte boundary
        !dir$ attributes align: 32:: Asmall                                                                                                       
        !dir$ attributes align: 32:: Bsmall                                                                                                       
        !dir$ attributes align: 32:: Csmall

    integer :: n_blocks

    integer :: i, j, k, bi, bj, bk

    ! finding max number of blocks that the square matrix can use

    n_blocks = M / BLOCK_SIZEL2 + merge(1, 0, mod(M,BLOCK_SIZEL2).gt.0)

    ! blocking scheme re-ordered so that the blocks go down in column order first in an attempt to reduce the memory strides taken
    ! between each loop

    do bj = 0, n_blocks-1
        j = bj * BLOCK_SIZEL2
        do bk = 0, n_blocks-1
            k = bk * BLOCK_SIZEL2
            do bi = 0, n_blocks-1
                i = bi * BLOCK_SIZEL2
!                write(*,*) 'got here'
                call do_blockL2(M, A, B, C, i, j, k, BLOCK_SIZEL2, Asmall, Bsmall, Csmall, BLOCK_SIZEL1)
!                write(*,*) 'got here'
            end do
        end do
    end do

end subroutine square_dgemm
