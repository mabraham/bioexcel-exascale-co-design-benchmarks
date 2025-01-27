!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2018  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

MODULE qmmm_gpw_forces
  USE cell_types,                      ONLY: cell_type,&
                                             pbc
  USE kinds,                           ONLY: dp
  USE qmmm_util,                        ONLY: spherical_cutoff_factor
  
  IMPLICIT NONE

  INTEGER :: do_par_atom=0   ! taken from input_constants.F
  
CONTAINS


! **************************************************************************************************
!> \brief Evaluates the contribution to the forces due to the Long Range
!>      part of the QM/MM potential computed collocating the Electrostatic
!>      Gaussian Potential.
!>      08.2004 created [tlaino]
!> \author Teodoro Laino
! **************************************************************************************************
  SUBROUTINE qmmm_forces_with_gaussian_LG  (pgfs_size,&
       cgrid_pw_grid_dr, cgrid_pw_grid_dvol, cgrid_pw_grid_bounds, cgrid_pw_grid_bounds_local, cgrid_pw_grid_cr3d,&
       num_mm_atoms,&
       mm_charges,& 
       mm_atom_index,&
       mm_particles_r,&
       para_env_num_pe, para_env_mepos,&
       Forces,&
       per_pot_cr3d, per_pot_npts, per_pot_dr, per_pot_mm_atom_index,&
       mm_cell,&
       dOmmOqm,&
       iw,&
       par_scheme,&
       qmmm_spherical_cutoff,&
       shells)
    
      INTEGER, INTENT(IN)                                :: pgfs_size
      REAL(KIND=dp), DIMENSION(3)                        :: cgrid_pw_grid_dr
      REAL(KIND=dp)                                      :: cgrid_pw_grid_dvol
      INTEGER, DIMENSION(2, 3)                           :: cgrid_pw_grid_bounds
      INTEGER, DIMENSION(2, 3)                           :: cgrid_pw_grid_bounds_local
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: cgrid_pw_grid_cr3d
      INTEGER, INTENT(IN)                                :: num_mm_atoms
      REAL(KIND=dp), DIMENSION(:), POINTER               :: mm_charges 
      INTEGER, DIMENSION(:), POINTER                     :: mm_atom_index
      REAL(KIND=dp), DIMENSION(:,:), POINTER             :: mm_particles_r  
      INTEGER                                            :: para_env_num_pe
      INTEGER                                            :: para_env_mepos
      REAL(KIND=dp), DIMENSION(:, :), POINTER            :: Forces
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: per_pot_cr3d
      INTEGER, DIMENSION(3)                              :: per_pot_npts
      REAL(KIND=dp), DIMENSION(3)                        :: per_pot_dr
      INTEGER, DIMENSION(:), POINTER                     :: per_pot_mm_atom_index
      TYPE(cell_type), POINTER                           :: mm_cell
      REAL(KIND=dp), DIMENSION(3), INTENT(IN)            :: dOmmOqm
      INTEGER, INTENT(IN)                                :: iw, par_scheme
      REAL(KIND=dp), DIMENSION(2), INTENT(IN)            :: qmmm_spherical_cutoff
      LOGICAL                                            :: shells
      
      INTEGER :: i, ii1, ii2, ii3, ii4, ij1, ij2, ij3, ij4, ik1, ik2, ik3, ik4, Imm, &
         IndMM, IRadTyp, ivec(3), j, k, LIndMM, my_i, my_j, my_k, myind
      INTEGER, DIMENSION(2, 3)                           :: bo, gbo
      REAL(KIND=dp) :: a1, a2, a3, abc_X(4,4), abc_X_Y(4), b1, b2, b3, c1, c2, c3, d1, d2, d3, &
         dr1, dr1c, dr1i, dr2, dr2c, dr2i, dr3, dr3c, dr3i, dvol, e1, e2, e3, f1, f2, f3, fac, &
         ft1, ft2, ft3, g1, g2, g3, h1, h2, h3, p1, p2, p3, q1, q2, q3, qt, r1, r2, r3, rt1, rt2, &
         rt3, rv1, rv2, rv3, s1, s1d, s1o, s2, s2d, s2o, s3, s3d, s3o, s4, s4d, s4o, &
         sph_chrg_factor, t1, t1d, t1o, t2, t2d, t2o, t3, t3d, t3o, t4, t4d, t4o, u1, u2, u3, v1, &
         v1d, v1o, v2, v2d, v2o, v3, v3d, v3o, v4, v4d, v4o, xd1, xd2, xd3, xs1, xs2, xs3
      REAL(KIND=dp), ALLOCATABLE, DIMENSION(:, :)        :: LForces
      REAL(KIND=dp), DIMENSION(3)                        :: ra, val, vec
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: grid, grid2
      
    NULLIFY(grid)
    ALLOCATE(LForces(3,num_mm_atoms))
    LForces = 0.0_dp
    dr1c  = cgrid_pw_grid_dr(1)
    dr2c  = cgrid_pw_grid_dr(2)
    dr3c  = cgrid_pw_grid_dr(3)
    dvol  = cgrid_pw_grid_dvol
    gbo   = cgrid_pw_grid_bounds
    bo    = cgrid_pw_grid_bounds_local
    grid  => cgrid_pw_grid_cr3d
    IF (par_scheme==do_par_atom) myind = 0
    Radius: DO IRadTyp = 1, pgfs_size
       grid2 => per_pot_cr3d
       dr1  = per_pot_dr(1)
       dr2  = per_pot_dr(2)
       dr3  = per_pot_dr(3)
       dr1i = 1.0_dp / dr1
       dr2i = 1.0_dp / dr2
       dr3i = 1.0_dp / dr3
       Atoms: DO Imm = 1, SIZE(per_pot_mm_atom_index)
          IF (par_scheme==do_par_atom) THEN
             myind = myind + 1
             IF (MOD(myind,para_env_num_pe)/=para_env_mepos) CYCLE
          END IF
          LIndMM    =   per_pot_mm_atom_index(Imm)
          IndMM     =   per_pot_mm_atom_index(LIndMM)
          IF (shells) THEN
             ra(:)     =   pbc(mm_particles_r(LIndMM,:)-dOmmOqm, mm_cell)+dOmmOqm
          ELSE
             ra(:)     =   pbc(mm_particles_r(IndMM, :)-dOmmOqm, mm_cell)+dOmmOqm
          END IF
          qt        =   mm_charges(LIndMM)
          ! Possible Spherical Cutoff
          IF (qmmm_spherical_cutoff(1)>0.0_dp) THEN
             CALL spherical_cutoff_factor(qmmm_spherical_cutoff, ra, sph_chrg_factor)
             qt = qt * sph_chrg_factor
          END IF
          IF (ABS(qt)<= EPSILON(0.0_dp)) CYCLE Atoms
          rt1 = ra(1)
          rt2 = ra(2)
          rt3 = ra(3)
          ft1 = 0.0_dp
          ft2 = 0.0_dp
          ft3 = 0.0_dp
          LoopOnGrid: DO k = bo(1,3), bo(2,3)
             my_k = k-gbo(1,3)
             xs3  = REAL(my_k,dp)*dr3c
             my_j = bo(1,2)-gbo(1,2)
             xs2 = REAL(my_j,dp)*dr2c
             rv3 = rt3 - xs3
             vec(3) = rv3
             ivec(3) = FLOOR(vec(3)/per_pot_dr(3))
                   ik1 = MODULO(ivec(3)-1,per_pot_npts(3))+1
                   ik2 = MODULO(ivec(3)  ,per_pot_npts(3))+1
                   ik3 = MODULO(ivec(3)+1,per_pot_npts(3))+1
                   ik4 = MODULO(ivec(3)+2,per_pot_npts(3))+1
             xd3  = (vec(3)/dr3)-REAL(ivec(3),kind=dp)
             p1  = 3.0_dp + xd3
             p2  = p1*p1
             p3  = p2*p1
             q1  = 2.0_dp + xd3
             q2  = q1*q1
             q3  = q2*q1
             r1  = 1.0_dp + xd3
             r2  = r1*r1
             r3  = r2*r1
             u1  = xd3
             u2  = u1*u1
             u3  = u2*u1
             v1o =   1.0_dp/6.0_dp * (64.0_dp - 48.0_dp*p1 + 12.0_dp*p2 - p3)
             v2o = -22.0_dp/3.0_dp + 10.0_dp*q1 - 4.0_dp*q2 + 0.5_dp*q3
             v3o =   2.0_dp/3.0_dp -  2.0_dp*r1 + 2.0_dp*r2 - 0.5_dp*r3
             v4o =   1.0_dp/6.0_dp*u3
             v1d =  -8.0_dp + 4.0_dp*p1 - 0.5_dp*p2
             v2d =  10.0_dp - 8.0_dp*q1 + 1.5_dp*q2
             v3d =  -2.0_dp + 4.0_dp*r1 - 1.5_dp*r2
             v4d =   0.5_dp*u2
             DO j =  bo(1,2), bo(2,2)
                my_i= bo(1,1)-gbo(1,1)
                xs1 = REAL(my_i,dp)*dr1c
                rv2 = rt2 - xs2
                vec(2) = rv2
                ivec(2) = FLOOR(vec(2)/per_pot_dr(2))
                   ij1 = MODULO(ivec(2)-1,per_pot_npts(2))+1
                   ij2 = MODULO(ivec(2)  ,per_pot_npts(2))+1
                   ij3 = MODULO(ivec(2)+1,per_pot_npts(2))+1
                   ij4 = MODULO(ivec(2)+2,per_pot_npts(2))+1
                xd2  = (vec(2)/dr2)-REAL(ivec(2),kind=dp)
                e1  = 3.0_dp + xd2
                e2  = e1*e1
                e3  = e2*e1
                f1  = 2.0_dp + xd2
                f2  = f1*f1
                f3  = f2*f1
                g1  = 1.0_dp + xd2
                g2  = g1*g1
                g3  = g2*g1
                h1  = xd2
                h2  = h1*h1
                h3  = h2*h1
                s1o =   1.0_dp/6.0_dp * (64.0_dp - 48.0_dp*e1 + 12.0_dp*e2 - e3)
                s2o = -22.0_dp/3.0_dp + 10.0_dp*f1 - 4.0_dp*f2 + 0.5_dp*f3
                s3o =   2.0_dp/3.0_dp -  2.0_dp*g1 + 2.0_dp*g2 - 0.5_dp*g3
                s4o =   1.0_dp/6.0_dp*h3
                s1d =  -8.0_dp + 4.0_dp*e1 - 0.5_dp*e2
                s2d =  10.0_dp - 8.0_dp*f1 + 1.5_dp*f2
                s3d =  -2.0_dp + 4.0_dp*g1 - 1.5_dp*g2
                s4d =   0.5_dp*h2
                DO i =  bo(1,1), bo(2,1)
                   rv1 = rt1 - xs1
                   vec(1) = rv1
                   ivec(1) = FLOOR(vec(1)/per_pot_dr(1))
                   ii1 = MODULO(ivec(1)-1,per_pot_npts(1))+1
                   ii2 = MODULO(ivec(1)  ,per_pot_npts(1))+1
                   ii3 = MODULO(ivec(1)+1,per_pot_npts(1))+1
                   ii4 = MODULO(ivec(1)+2,per_pot_npts(1))+1
                   xd1  = (vec(1)/dr1)-REAL(ivec(1),kind=dp)
                   a1  = 3.0_dp + xd1
                   a2  = a1*a1
                   a3  = a2*a1
                   b1  = 2.0_dp + xd1
                   b2  = b1*b1
                   b3  = b2*b1
                   c1  = 1.0_dp + xd1
                   c2  = c1*c1
                   c3  = c2*c1
                   d1  = xd1
                   d2  = d1*d1
                   d3  = d2*d1
                   t1o =   1.0_dp/6.0_dp * (64.0_dp - 48.0_dp*a1 + 12.0_dp*a2 - a3)
                   t2o = -22.0_dp/3.0_dp + 10.0_dp*b1 - 4.0_dp*b2 + 0.5_dp*b3
                   t3o =   2.0_dp/3.0_dp -  2.0_dp*c1 + 2.0_dp*c2 - 0.5_dp*c3
                   t4o =   1.0_dp/6.0_dp*d3
                   t1d =  -8.0_dp + 4.0_dp*a1 - 0.5_dp*a2
                   t2d =  10.0_dp - 8.0_dp*b1 + 1.5_dp*b2
                   t3d =  -2.0_dp + 4.0_dp*c1 - 1.5_dp*c2
                   t4d =   0.5_dp*d2


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Shell code corresponding to the same grid-based calculation as executed in this subroutine?
! # v then t then s
!
! for ii in 1 2 3; do
! if [[ $ii == 1 ]]; then ld=t; fi
! if [[ $ii == 2 ]]; then ld=s; fi
! if [[ $ii == 3 ]]; then ld=v; fi
! #
! for l in t s v; do
! for i in 1 2 3 4; do
! if [[ $ld == $l ]]; then
!  echo "$l$i = $l${i}d*dr${ii}i"
! else
!  echo "$l$i = $l${i}o"
! fi
! done
! done
! #
! for i in 1 2 3 4; do
! for j in 1 2 3 4; do
! echo -n "abc_X($i,$j) = "
! for k in 1 2 3 4; do
! if [ $k == 4 ]; then
! echo "grid2(ii$i,ij$j,ik$k)*v$k"
! else
! echo -n "grid2(ii$i,ij$j,ik$k)*v$k + "
! fi
! done
! done
! done
! echo ""
! for j in 1 2 3 4; do
! echo -n "abc_X_Y($j) = "
! for k in 1 2 3 4; do
! if [ $k == 4 ]; then
! echo "abc_X($k,$j)*t$k"
! else
! echo -n "abc_X($k,$j)*t$k + "
! fi
! done
! done
! echo ""
! echo -n "val($ii) = "
! for k in 1 2 3 4; do
! if [ $k == 4 ]; then
! echo "abc_X_Y($k)*s$k"
! else
! echo -n "abc_X_Y($k)*s$k + "
! fi
! done
! echo ""
! done

                   t1     = t1d*dr1i
                   t2     = t2d*dr1i
                   t3     = t3d*dr1i
                   t4     = t4d*dr1i
                   s1     = s1o
                   s2     = s2o
                   s3     = s3o
                   s4     = s4o
                   v1     = v1o
                   v2     = v2o
                   v3     = v3o
                   v4     = v4o
                   abc_X(1,1) = grid2(ii1,ij1,ik1)*v1 + grid2(ii1,ij1,ik2)*v2 + grid2(ii1,ij1,ik3)*v3 + grid2(ii1,ij1,ik4)*v4
                   abc_X(1,2) = grid2(ii1,ij2,ik1)*v1 + grid2(ii1,ij2,ik2)*v2 + grid2(ii1,ij2,ik3)*v3 + grid2(ii1,ij2,ik4)*v4
                   abc_X(1,3) = grid2(ii1,ij3,ik1)*v1 + grid2(ii1,ij3,ik2)*v2 + grid2(ii1,ij3,ik3)*v3 + grid2(ii1,ij3,ik4)*v4
                   abc_X(1,4) = grid2(ii1,ij4,ik1)*v1 + grid2(ii1,ij4,ik2)*v2 + grid2(ii1,ij4,ik3)*v3 + grid2(ii1,ij4,ik4)*v4
                   abc_X(2,1) = grid2(ii2,ij1,ik1)*v1 + grid2(ii2,ij1,ik2)*v2 + grid2(ii2,ij1,ik3)*v3 + grid2(ii2,ij1,ik4)*v4
                   abc_X(2,2) = grid2(ii2,ij2,ik1)*v1 + grid2(ii2,ij2,ik2)*v2 + grid2(ii2,ij2,ik3)*v3 + grid2(ii2,ij2,ik4)*v4
                   abc_X(2,3) = grid2(ii2,ij3,ik1)*v1 + grid2(ii2,ij3,ik2)*v2 + grid2(ii2,ij3,ik3)*v3 + grid2(ii2,ij3,ik4)*v4
                   abc_X(2,4) = grid2(ii2,ij4,ik1)*v1 + grid2(ii2,ij4,ik2)*v2 + grid2(ii2,ij4,ik3)*v3 + grid2(ii2,ij4,ik4)*v4
                   abc_X(3,1) = grid2(ii3,ij1,ik1)*v1 + grid2(ii3,ij1,ik2)*v2 + grid2(ii3,ij1,ik3)*v3 + grid2(ii3,ij1,ik4)*v4
                   abc_X(3,2) = grid2(ii3,ij2,ik1)*v1 + grid2(ii3,ij2,ik2)*v2 + grid2(ii3,ij2,ik3)*v3 + grid2(ii3,ij2,ik4)*v4
                   abc_X(3,3) = grid2(ii3,ij3,ik1)*v1 + grid2(ii3,ij3,ik2)*v2 + grid2(ii3,ij3,ik3)*v3 + grid2(ii3,ij3,ik4)*v4
                   abc_X(3,4) = grid2(ii3,ij4,ik1)*v1 + grid2(ii3,ij4,ik2)*v2 + grid2(ii3,ij4,ik3)*v3 + grid2(ii3,ij4,ik4)*v4
                   abc_X(4,1) = grid2(ii4,ij1,ik1)*v1 + grid2(ii4,ij1,ik2)*v2 + grid2(ii4,ij1,ik3)*v3 + grid2(ii4,ij1,ik4)*v4
                   abc_X(4,2) = grid2(ii4,ij2,ik1)*v1 + grid2(ii4,ij2,ik2)*v2 + grid2(ii4,ij2,ik3)*v3 + grid2(ii4,ij2,ik4)*v4
                   abc_X(4,3) = grid2(ii4,ij3,ik1)*v1 + grid2(ii4,ij3,ik2)*v2 + grid2(ii4,ij3,ik3)*v3 + grid2(ii4,ij3,ik4)*v4
                   abc_X(4,4) = grid2(ii4,ij4,ik1)*v1 + grid2(ii4,ij4,ik2)*v2 + grid2(ii4,ij4,ik3)*v3 + grid2(ii4,ij4,ik4)*v4

                   abc_X_Y(1) = abc_X(1,1)*t1 + abc_X(2,1)*t2 + abc_X(3,1)*t3 + abc_X(4,1)*t4
                   abc_X_Y(2) = abc_X(1,2)*t1 + abc_X(2,2)*t2 + abc_X(3,2)*t3 + abc_X(4,2)*t4
                   abc_X_Y(3) = abc_X(1,3)*t1 + abc_X(2,3)*t2 + abc_X(3,3)*t3 + abc_X(4,3)*t4
                   abc_X_Y(4) = abc_X(1,4)*t1 + abc_X(2,4)*t2 + abc_X(3,4)*t3 + abc_X(4,4)*t4

                   val(1) = abc_X_Y(1)*s1 + abc_X_Y(2)*s2 + abc_X_Y(3)*s3 + abc_X_Y(4)*s4

                   t1     = t1o
                   t2     = t2o
                   t3     = t3o
                   t4     = t4o
                   s1     = s1d*dr2i
                   s2     = s2d*dr2i
                   s3     = s3d*dr2i
                   s4     = s4d*dr2i

                   abc_X_Y(1) = abc_X(1,1)*t1 + abc_X(2,1)*t2 + abc_X(3,1)*t3 + abc_X(4,1)*t4
                   abc_X_Y(2) = abc_X(1,2)*t1 + abc_X(2,2)*t2 + abc_X(3,2)*t3 + abc_X(4,2)*t4
                   abc_X_Y(3) = abc_X(1,3)*t1 + abc_X(2,3)*t2 + abc_X(3,3)*t3 + abc_X(4,3)*t4
                   abc_X_Y(4) = abc_X(1,4)*t1 + abc_X(2,4)*t2 + abc_X(3,4)*t3 + abc_X(4,4)*t4

                   val(2) = abc_X_Y(1)*s1 + abc_X_Y(2)*s2 + abc_X_Y(3)*s3 + abc_X_Y(4)*s4

                   t1     = t1o
                   t2     = t2o
                   t3     = t3o
                   t4     = t4o
                   s1     = s1o
                   s2     = s2o
                   s3     = s3o
                   s4     = s4o
                   v1     = v1d*dr3i
                   v2     = v2d*dr3i
                   v3     = v3d*dr3i
                   v4     = v4d*dr3i
                   abc_X(1,1) = grid2(ii1,ij1,ik1)*v1 + grid2(ii1,ij1,ik2)*v2 + grid2(ii1,ij1,ik3)*v3 + grid2(ii1,ij1,ik4)*v4
                   abc_X(1,2) = grid2(ii1,ij2,ik1)*v1 + grid2(ii1,ij2,ik2)*v2 + grid2(ii1,ij2,ik3)*v3 + grid2(ii1,ij2,ik4)*v4
                   abc_X(1,3) = grid2(ii1,ij3,ik1)*v1 + grid2(ii1,ij3,ik2)*v2 + grid2(ii1,ij3,ik3)*v3 + grid2(ii1,ij3,ik4)*v4
                   abc_X(1,4) = grid2(ii1,ij4,ik1)*v1 + grid2(ii1,ij4,ik2)*v2 + grid2(ii1,ij4,ik3)*v3 + grid2(ii1,ij4,ik4)*v4
                   abc_X(2,1) = grid2(ii2,ij1,ik1)*v1 + grid2(ii2,ij1,ik2)*v2 + grid2(ii2,ij1,ik3)*v3 + grid2(ii2,ij1,ik4)*v4
                   abc_X(2,2) = grid2(ii2,ij2,ik1)*v1 + grid2(ii2,ij2,ik2)*v2 + grid2(ii2,ij2,ik3)*v3 + grid2(ii2,ij2,ik4)*v4
                   abc_X(2,3) = grid2(ii2,ij3,ik1)*v1 + grid2(ii2,ij3,ik2)*v2 + grid2(ii2,ij3,ik3)*v3 + grid2(ii2,ij3,ik4)*v4
                   abc_X(2,4) = grid2(ii2,ij4,ik1)*v1 + grid2(ii2,ij4,ik2)*v2 + grid2(ii2,ij4,ik3)*v3 + grid2(ii2,ij4,ik4)*v4
                   abc_X(3,1) = grid2(ii3,ij1,ik1)*v1 + grid2(ii3,ij1,ik2)*v2 + grid2(ii3,ij1,ik3)*v3 + grid2(ii3,ij1,ik4)*v4
                   abc_X(3,2) = grid2(ii3,ij2,ik1)*v1 + grid2(ii3,ij2,ik2)*v2 + grid2(ii3,ij2,ik3)*v3 + grid2(ii3,ij2,ik4)*v4
                   abc_X(3,3) = grid2(ii3,ij3,ik1)*v1 + grid2(ii3,ij3,ik2)*v2 + grid2(ii3,ij3,ik3)*v3 + grid2(ii3,ij3,ik4)*v4
                   abc_X(3,4) = grid2(ii3,ij4,ik1)*v1 + grid2(ii3,ij4,ik2)*v2 + grid2(ii3,ij4,ik3)*v3 + grid2(ii3,ij4,ik4)*v4
                   abc_X(4,1) = grid2(ii4,ij1,ik1)*v1 + grid2(ii4,ij1,ik2)*v2 + grid2(ii4,ij1,ik3)*v3 + grid2(ii4,ij1,ik4)*v4
                   abc_X(4,2) = grid2(ii4,ij2,ik1)*v1 + grid2(ii4,ij2,ik2)*v2 + grid2(ii4,ij2,ik3)*v3 + grid2(ii4,ij2,ik4)*v4
                   abc_X(4,3) = grid2(ii4,ij3,ik1)*v1 + grid2(ii4,ij3,ik2)*v2 + grid2(ii4,ij3,ik3)*v3 + grid2(ii4,ij3,ik4)*v4
                   abc_X(4,4) = grid2(ii4,ij4,ik1)*v1 + grid2(ii4,ij4,ik2)*v2 + grid2(ii4,ij4,ik3)*v3 + grid2(ii4,ij4,ik4)*v4

                   abc_X_Y(1) = abc_X(1,1)*t1 + abc_X(2,1)*t2 + abc_X(3,1)*t3 + abc_X(4,1)*t4
                   abc_X_Y(2) = abc_X(1,2)*t1 + abc_X(2,2)*t2 + abc_X(3,2)*t3 + abc_X(4,2)*t4
                   abc_X_Y(3) = abc_X(1,3)*t1 + abc_X(2,3)*t2 + abc_X(3,3)*t3 + abc_X(4,3)*t4
                   abc_X_Y(4) = abc_X(1,4)*t1 + abc_X(2,4)*t2 + abc_X(3,4)*t3 + abc_X(4,4)*t4

                   val(3) = abc_X_Y(1)*s1 + abc_X_Y(2)*s2 + abc_X_Y(3)*s3 + abc_X_Y(4)*s4
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

                   fac = grid(i,j,k)
                   ft1 = ft1 + val(1) * fac
                   ft2 = ft2 + val(2) * fac
                   ft3 = ft3 + val(3) * fac
                   xs1 = xs1 + dr1c
                END DO
                xs2 = xs2 + dr2c
             END DO
          END DO LoopOnGrid
          qt = - qt * dvol
          LForces(1,LindMM) = ft1 * qt
          LForces(2,LindMM) = ft2 * qt
          LForces(3,LindMM) = ft3 * qt

          Forces(1,LIndMM) = Forces(1,LIndMM) + LForces(1,LindMM)
          Forces(2,LIndMM) = Forces(2,LIndMM) + LForces(2,LindMM)
          Forces(3,LIndMM) = Forces(3,LIndMM) + LForces(3,LindMM)
       END DO Atoms
    END DO Radius
    DEALLOCATE(LForces)
  END SUBROUTINE qmmm_forces_with_gaussian_LG

END MODULE qmmm_gpw_forces
