//
//  QEF.swift
//  DualMarchingCuboids
//
//  Created by Andy Geers on 06/09/2020.
//

import Foundation
import Euclid

// From Boris the Brave:
// https://github.com/BorisTheBrave/mc-dc/blob/a165b326849d8814fb03c963ad33a9faf6cc6dea/qef.py
extension Cuboid {
    func solveQEF(positions : [Vector], normals : [Vector], bias : Bool = true, boundary : Bool = true, clip : Bool = true) -> Vector {
        // The error term we are trying to minimize is sum( dot(x-v[i], n[i]) ^ 2)
        // This should be minimized over the unit square with top left point (x, y)

        // In other words, minimize || A * x - b || ^2 where A and b are a matrix and vector
        // derived from v and n
        // The heavy lifting is done by the QEF class, but this function includes some important
        // tricks to cope with edge cases

        // This is demonstration code and isn't optimized, there are many good C++ implementations
        // out there if you need speed.

        if bias {
            // Add extra normals that add extra error the further we go
            // from the cell, this encourages the final result to be
            // inside the cell
            // These normals are shorter than the input normals
            // as that makes the bias weaker,  we want them to only
            // really be important when the input is ambiguous

            // Take a simple average of positions as the point we will
            // pull towards.
            mass_point = numpy.mean(positions, axis=0)

            normals.append([settings.BIAS_STRENGTH, 0, 0])
            positions.append(mass_point)
            normals.append([0, settings.BIAS_STRENGTH, 0])
            positions.append(mass_point)
            normals.append([0, 0, settings.BIAS_STRENGTH])
            positions.append(mass_point)
        }
        
        qef = QEF.make_3d(positions, normals)

        let (residual, v) = qef.solve()

        if settings.BOUNDARY {

            // It's entirely possible that the best solution to the qef is not actually
            // inside the cell.
            if !inside((residual, v)) {
                // If so, we constrain the the qef to the 6
                // planes bordering the cell, and find the best point of those
                r1 = qef.fix_axis(0, x + 0).solve()
                r2 = qef.fix_axis(0, x + 1).solve()
                r3 = qef.fix_axis(1, y + 0).solve()
                r4 = qef.fix_axis(1, y + 1).solve()
                r5 = qef.fix_axis(2, z + 0).solve()
                r6 = qef.fix_axis(2, z + 1).solve()

                rs = list(filter(inside, [r1, r2, r3, r4, r5, r6]))

                if rs.isEmpty {
                    // It's still possible that those planes (which are infinite)
                    // cause solutions outside the box.
                    // So now try the 12 lines bordering the cell
                    r1  = qef.fix_axis(1, y + 0).fix_axis(0, x + 0).solve()
                    r2  = qef.fix_axis(1, y + 1).fix_axis(0, x + 0).solve()
                    r3  = qef.fix_axis(1, y + 0).fix_axis(0, x + 1).solve()
                    r4  = qef.fix_axis(1, y + 1).fix_axis(0, x + 1).solve()
                    r5  = qef.fix_axis(2, z + 0).fix_axis(0, x + 0).solve()
                    r6  = qef.fix_axis(2, z + 1).fix_axis(0, x + 0).solve()
                    r7  = qef.fix_axis(2, z + 0).fix_axis(0, x + 1).solve()
                    r8  = qef.fix_axis(2, z + 1).fix_axis(0, x + 1).solve()
                    r9  = qef.fix_axis(2, z + 0).fix_axis(1, y + 0).solve()
                    r10 = qef.fix_axis(2, z + 1).fix_axis(1, y + 0).solve()
                    r11 = qef.fix_axis(2, z + 0).fix_axis(1, y + 1).solve()
                    r12 = qef.fix_axis(2, z + 1).fix_axis(1, y + 1).solve()

                    rs = list(filter(inside, [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12]))
                }
                
                if rs.isEmpty {
                    // So finally, we evaluate which corner
                    // of the cell looks best
                    r1 = qef.eval_with_pos((x + 0, y + 0, z + 0))
                    r2 = qef.eval_with_pos((x + 0, y + 0, z + 1))
                    r3 = qef.eval_with_pos((x + 0, y + 1, z + 0))
                    r4 = qef.eval_with_pos((x + 0, y + 1, z + 1))
                    r5 = qef.eval_with_pos((x + 1, y + 0, z + 0))
                    r6 = qef.eval_with_pos((x + 1, y + 0, z + 1))
                    r7 = qef.eval_with_pos((x + 1, y + 1, z + 0))
                    r8 = qef.eval_with_pos((x + 1, y + 1, z + 1))

                    rs = list(filter(inside, [r1, r2, r3, r4, r5, r6, r7, r8]))
                }
                
                // Pick the best of the available options
                let (residual, v) = min(rs)
            }
        }

        if clip {
            // Crudely force v to be inside the cell
            v[0] = numpy.clip(v[0], x, x + 1)
            v[1] = numpy.clip(v[1], y, y + 1)
            v[2] = numpy.clip(v[2], z, z + 1)
        }

        return Vector(v[0], v[1], v[2])
    }
}
