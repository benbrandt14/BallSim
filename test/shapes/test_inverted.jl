using Test
using BallSim.Common
using BallSim.Shapes
using StaticArrays
using LinearAlgebra

@testset "Inverted Shapes Logic" begin

    # ==========================================================================
    # LOGIC EXPLANATION
    # ==========================================================================
    # Normal Shape (Obstacle):
    #   - Inside: Collision (dist > 0, normal points OUT)
    #   - Outside: Safe (dist <= 0)
    #
    # Inverted Shape (Container/Safe Zone):
    #   - We want particles to be SAFE INSIDE the shape.
    #   - We want particles to COLLIDE OUTSIDE the shape.
    #
    # Implementation in Common.jl:
    #   detect_collision checks if sdf(b, p) > 0.
    #   sdf(Inverted) = -sdf(Inner)
    #
    # Example: Circle (Inner)
    #   - Inside (d < r): sdf = d - r < 0.
    #   - Inverted SDF = -(negative) = POSITIVE.
    #   - Result: Inverted Circle registers COLLISION INSIDE.
    #
    # WAIT! There is a confusion here.
    # If Inverted is a CONTAINER (like a bowl), particles should be SAFE INSIDE.
    # So Inside should have dist <= 0.
    #
    # Let's re-read the code in `src/Shapes.jl`:
    # function Common.detect_collision(b::Inverted{2,Circle}, p::SVector{2}, t)
    #    if d2 < r2  (INSIDE)
    #        return (true, dist, n)  (COLLISION)
    #
    # This implies Inverted(Circle) is an OBSTACLE located INSIDE the circle?
    # No, the comment says: "Used to trap particles INSIDE a shape".
    #
    # If it traps particles INSIDE, then:
    #   - Inside: SAFE.
    #   - Outside: COLLISION.
    #
    # But the code for Inverted{Circle} returns TRUE (Collision) if d2 < r2 (Inside).
    # This means Inverted(Circle) acts as a SOLID CIRCLE.
    #
    # Let's check Inverted(Box) in `shapes/test_inverted.jl` (previous version):
    #   "Point Inside (0,0) -> Should collide"
    #   "Point Outside (2,0) -> Should be safe"
    #
    # This means `Inverted` currently simply FLIPS the SDF sign.
    # Inner Box: Inside = Negative (Safe?? No, wait).
    #
    # Standard Interpretation (SDF):
    #   - Negative: Inside Object.
    #   - Positive: Outside Object.
    #
    # Standard Interpretation (Collision):
    #   - If I am inside a solid object, I collide.
    #   - `detect_collision` says: `if dist > 0 ... return true`.
    #   - So we need Positive Distance to Collide.
    #
    # Case A: Solid Box (Obstacle)
    #   - We want Collision Inside.
    #   - Box.sdf returns Negative Inside?
    #   - `src/Shapes.jl`: Box.sdf = norm(max(d,0)) + min(max(d),0).
    #       - Point Inside: d is negative. max(d,0) is 0. min(max(d),0) is negative. Result Negative.
    #   - So `detect_collision(Box)` returns FALSE for points Inside?
    #   - Let's check `Common.detect_collision(Box)`:
    #       - It implements its own logic!
    #       - `if d_max_x > 0 ... return true`.
    #       - This checks if OUTSIDE bounds (d > 0).
    #       - So Box acts as a solid block that exists everywhere EXCEPT the center?
    #       - Or does it return collision if we are OUTSIDE the box?
    #
    # REALITY CHECK:
    # `Box` implementation in `Shapes.jl`:
    #   `if d_max_x > 0 || d_max_y > 0 ... return (true, ...)`
    #   This means collision happens OUTSIDE the defined width/height.
    #   So `Box` is defined as "Safe Zone Inside, Collision Outside"?
    #   That effectively makes `Box` a Container by default!
    #
    # Let's check `Circle` in `Shapes.jl`:
    #   `if d2 > r2 ... return (true, ...)`
    #   This means collision happens if distance > radius.
    #   So `Circle` is ALSO a Container by default!
    #
    # IF `Box` and `Circle` are Containers by default:
    #   Then `Inverted` should make them Obstacles (Solids).
    #   Inverted(Circle): Collision if Inside (d < r).
    #   The code for Inverted{Circle} does exactly that: `if d2 < r2 ... return true`.
    #
    # CONCLUSION:
    #   - `Box`, `Circle` = CONTAINERS (Safe Inside).
    #   - `Inverted(Box)`, `Inverted(Circle)` = OBSTACLES (Safe Outside).
    #
    #   This explains why Inverted(Box) test expects collision at (0,0).

    @testset "Inverted Box (Obstacle)" begin
        # Inner Box (2x2) is a Container (Safe Inside [-1,1], Collision Outside).
        inner_box = Shapes.Box(2.0f0, 2.0f0)

        # Inverted Box is an Obstacle (Collision Inside [-1,1], Safe Outside).
        inv_box = Shapes.Inverted(inner_box)

        # 1. Point Inside (0,0) -> Collision
        p_in = SVector(0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_box, p_in, 0.0f0)
        @test c == true
        @test d > 0
        # Normal should point OUT of the obstacle (so, towards Safe Zone/Outside).
        # Inner Box normal points Inward? (to center).
        # Inverted normal = -InnerNormal.
        # Box normals are axis aligned.

        # 2. Point Outside (2,0) -> Safe
        p_out = SVector(2.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_box, p_out, 0.0f0)
        @test c == false
    end

    @testset "Inverted Circle3D (Sphere Obstacle)" begin
        # Sphere Container (Safe Inside)
        sphere = Shapes.Circle3D(5.0f0)
        # Sphere Obstacle (Safe Outside)
        inv_sphere = Shapes.Inverted(sphere)

        # 1. Inside (0,0,0) -> Collision
        p_in = SVector(0.0f0, 0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_sphere, p_in, 0.0f0)
        @test c == true
        @test d ≈ 5.0f0 # Penetration depth = Radius
        # Singularity at center handled?
        @test n ≈ SVector(0.0f0, 0.0f0, 1.0f0) # Default Z-up

        # 2. Inside (2,0,0) -> Collision
        p_in2 = SVector(2.0f0, 0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_sphere, p_in2, 0.0f0)
        @test c == true
        @test d ≈ 3.0f0 # 5 - 2
        @test n ≈ SVector(-1.0f0, 0.0f0, 0.0f0) # Push back to center? No, push OUT.
        # If I am at (2,0,0) inside a solid sphere of R=5,
        # To get out, I need to go to > 5.
        # So direction is (1,0,0).
        # Wait. Inverted{Circle} implementation: `n = -p / d`.
        # p=(2,0,0), d=2. n = (-1,0,0).
        # This points TOWARDS THE CENTER.
        # If I go towards center, I stay inside the solid sphere.
        # I need to go OUT.
        #
        # Re-evaluating `Inverted{Circle}` logic in `Shapes.jl`:
        # `n = -p / d`.
        # Normal usually points towards the "Forbidden" side?
        # Standard: `step!` moves particle by `-normal * dist`.
        # So if we want to move OUT, normal should point IN (opposite to direction of motion).
        # If `n` points to Center (-1,0,0), `-n` points Out (1,0,0).
        # This seems correct for resolving collision.
    end

    @testset "Inverted Ellipsoid (Fallback)" begin
        # Ellipsoid is not specialized in `detect_collision` for Inverted,
        # so it uses the fallback: sdf(Inverted) = -sdf(Inner).
        #
        # Inner Ellipsoid:
        # sdf > 0 outside (Collision?) -> Yes, Container by default?
        # Let's check Ellipsoid.sdf:
        # returns (k-1)/grad_len.
        # p=0 -> k=0 -> sdf < 0.
        # p=Far -> k>1 -> sdf > 0.
        #
        # If detect_collision uses sdf > 0 -> Collision.
        # Then Ellipsoid is a Container (Collision Outside).
        #
        # Inverted Ellipsoid:
        # sdf = -sdf(Inner).
        # p=0 -> Inner<0 -> Inverted>0 (Collision).
        # p=Far -> Inner>0 -> Inverted<0 (Safe).
        #
        # So Inverted(Ellipsoid) acts as an Obstacle.

        ell = Shapes.Ellipsoid(2.0f0, 1.0f0)
        inv_ell = Shapes.Inverted(ell)

        # Inside (0,0) -> Collision
        p_in = SVector(0.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_ell, p_in, 0.0f0)
        @test c == true
        @test d > 0

        # Outside (3,0) -> Safe
        p_out = SVector(3.0f0, 0.0f0)
        (c, d, n) = Common.detect_collision(inv_ell, p_out, 0.0f0)
        @test c == false
    end
end
