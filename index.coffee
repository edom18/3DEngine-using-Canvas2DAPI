do (win = window, doc = window.document, exports = window.S3D or (window.S3D = {})) ->

    #Import
    {max, min, sqrt, tan, cos, sin, PI} = Math

    DEG_TO_RAD = PI / 180

    win.Float32Array = win.Float32Array or win.Array

# -------------------------------------------------------------------------------

    class Vertex
        constructor: (@vertecies) ->

        getZPosition: ->
            ret = 0
            cnt = 0
            for v, i in @vertecies by 4
                cnt++
                ret += @vertecies[i + 2] * @vertecies[i + 3]

            return ret / cnt

# -------------------------------------------------------------------------------

    ###*
        Vector3 class
        @constructor
        @param {number} x Position of x.
        @param {number} y Position of y.
        @param {number} z Position of z.
    ###
    class Vector3
        constructor: (@x = 0, @y = 0, @z = 0) ->
        zero: ->
            @x = @y = @z = 0;
            return @

        equal: (v) ->
            return (@x is v.x) and (@y is v.y) and (@z is v.z)

        set: (@x = 0, @y = 0, @z = 0) ->
            return @

        sub: (v) ->
            @x -= v.x
            @y -= v.y
            @z -= v.z
            return @

        subVectors: (a, b) ->
            @x = a.x - b.x
            @y = a.y - b.y
            @z = a.z - b.z
            return @

        add: (v) ->
            @x += v.x
            @y += v.y
            @z += v.z
            return @

        addVectors: (a, b) ->
            @x = a.x + b.x
            @y = a.y + b.y
            @z = a.z + b.z
            return @

        copy: (v) ->
            @x = v.x
            @y = v.y
            @z = v.z
            return @

        norm: ->
            return sqrt(@x * @x + @y * @y + @z * @z)

        normalize: ->
            nrm = @norm()

            if nrm isnt 0
                nrm = 1 / nrm
                @x *= nrm
                @y *= nrm
                @z *= nrm

            return @


        multiply: (v) ->
            @x *= v.x
            @y *= v.y
            @z *= v.z

            return @

        #scalar multiplication
        multiplyScalar: (s) ->
            @x *= s
            @y *= s
            @z *= s
            return @

        multiplyVectors: (a, b) ->
            @x = a.x * b.x
            @y = a.y * b.y
            @z = a.z * b.z
            return @

        #dot product
        dot: (v) ->
            return @x * v.x + @y * v.y + @z * v.z

        cross: (v, w) ->

            return @crossVectors(v, w) if w

            x = @x
            y = @y
            z = @z

            @x = (y * v.z) - (z * v.y)
            @y = (z * v.x) - (x * v.z)
            @z = (x * v.y) - (y * v.x)

            return @

        #cross product
        crossVectors: (v, w) ->
            @x = (w.y * v.z) - (w.z * v.y)
            @y = (w.z * v.x) - (w.x * v.z)
            @z = (w.x * v.y) - (w.y * v.x)

            return @

        applyMatrix4: (m) ->
            e = m.elements

            x = @x
            y = @y
            z = @z

            @x = e[0] * x + e[4] * y + e[8]  * z + e[12]
            @y = e[1] * x + e[5] * y + e[9]  * z + e[13]
            @z = e[2] * x + e[5] * y + e[10] * z + e[14]

            return @

        ###*
            射影投影座標変換

            計算された座標変換行列をスクリーンの座標系に変換するために計算する
            基本はスケーリング（&Y軸反転）と平行移動。
            行列で表すと
            w = width  / 2
            h = height / 2
            とすると
                        |w  0  0  0|
            M(screen) = |0 -h  0  0|
                        |0  0  1  0|
                        |w  h  0  1|

            4x4の変換行列を対象の1x4行列[x, y, z, 1]に適用する
            1x4行列と4x4行列の掛け算を行う

            |@_11 @_12 @_13 @_14|   |x|
            |@_21 @_22 @_23 @_24| x |y|
            |@_31 @_32 @_33 @_34|   |z|
            |@_41 @_42 @_43 @_44|   |1|

            @_4nは1x4行列の最後が1のため、ただ足すだけになる

            @param {Array.<number>} out
            @param {number} x
            @param {number} y
            @param {number} z
        ###
        applyProjection: (m, out) ->

            x = @x
            y = @y
            z = @z

            e = m.elements

            #Perspective divide
            w = (e[3] * x + e[7] * y + e[11] * z + e[15])

            _w = 1 / w
            _x = (e[0] * x + e[4] * y + e[8]  * z + e[12])
            _y = (e[1] * x + e[5] * y + e[9]  * z + e[13])
            _z = (e[2] * x + e[6] * y + e[10] * z + e[14])

            # クリップ空間外に出たものはレンダリングしない
            return false if not ((-w <= _x <= w) or (-w <= _y <= w) or (-w <= _z <= w))

            @x = _x * _w
            @y = _y * _w
            @z = _z * _w

            out[0] = @
            out[1] = w

            return @

        clone: ->
            vec3 = new Vector3
            vec3.copy @
            return vec3

        toArray: ->
            return [@x, @y, @z]

        toString: ->
            return "#{@x},#{@y},#{@z}"


# -------------------------------------------------------------------

    ###*
        Matrix2 class
        @constructor
    ###
    class Matrix2
        constructor: (m11 = 1, m12 = 0, m21 = 0, m22 = 1) ->

            @elements = te = new Float32Array 4

            # |1 0|
            # |0 1|
            # ----------
            # |m11 m12|
            # |m21 m22|
            # の行列で初期化

            te[0] = m11; te[2] = m12;
            te[1] = m21; te[3] = m22;

        ###*
            逆行列を生成
            
            [逆行列の公式]

            A = |a b|
                |c d|

            について、detA = ad - bc ≠0のときAの逆行列が存在する

            A^-1 = | d -b| * 1 / detA
                   |-c  a|
        ###
        getInvert: ->
            out = new Matrix2()
            oe  = out.elements
            te  = @elements

            det = te[0] * te[3] - te[2] * te[1]

            return null if 0.0001 > det > -0.0001

            oe[0] =  te[3] / det
            oe[1] = -te[1] / det
            oe[2] = -te[2] / det
            oe[3] =  te[0] / det

            return out

# -----------------------------------------------------------

    ###*
        Matrix4 class
        @constructor
        @param {boolean} cpy
    ###
    class Matrix4
        constructor: (cpy) ->
            @elements = new Float32Array 16
            if (cpy) then @copy cpy else @identity()

        identity: ->

            # 以下のように初期化
            # |1 0 0 0|
            # |0 1 0 0|
            # |0 0 1 0|
            # |0 0 0 1|
            #
            # |m11 m12 m13 m14|
            # |m21 m22 m23 m24|
            # |m31 m32 m33 m34|
            # |m41 m42 m43 m44|
            #
            # OpenGLでは以下の一次元配列となる（縦横に注意）
            # |m[0] m[4] m[8]  m[12]|
            # |m[1] m[5] m[9]  m[13]|
            # |m[2] m[6] m[10] m[14]|
            # |m[3] m[7] m[11] m[15]|

            te = @elements

            te[0] = 1; te[4] = 0; te[8]  = 0; te[12] = 0;
            te[1] = 0; te[5] = 1; te[9]  = 0; te[13] = 0;
            te[2] = 0; te[6] = 0; te[10] = 1; te[14] = 0;
            te[3] = 0; te[7] = 0; te[11] = 0; te[15] = 1;

            return @

        equal: (m) ->
            te = @elements
            me = m.elements

            return (
                (te[0] is me[0]) and (te[4] is me[4]) and (te[8]  is me[8] ) and (te[12] is me[12]) and
                (te[1] is me[1]) and (te[5] is me[5]) and (te[9]  is me[9] ) and (te[13] is me[13]) and
                (te[2] is me[2]) and (te[6] is me[6]) and (te[10] is me[10]) and (te[14] is me[14]) and
                (te[3] is me[3]) and (te[7] is me[7]) and (te[11] is me[11]) and (te[15] is me[15])
            )

        getInvert: ->
            out = new Matrix4
            oe  = out.elements
            te  = @elements

            a11 = te[0]; a12 = te[4]; a13 = te[8];  a14 = te[12];
            a21 = te[1]; a22 = te[5]; a23 = te[9];  a24 = te[13];
            a31 = te[2]; a32 = te[6]; a33 = te[10]; a34 = te[14];
            a41 = te[3]; a42 = te[7]; a43 = te[11]; a44 = te[15];

            det = (a11 * a22 * a33 * a44
            + a11 * a23 * a34 * a42
            + a11 * a24 * a32 * a43
            + a12 * a21 * a34 * a43
            + a12 * a23 * a31 * a44
            + a12 * a24 * a33 * a41
            + a13 * a21 * a32 * a44
            + a13 * a22 * a34 * a41
            + a13 * a24 * a31 * a42
            + a14 * a21 * a33 * a42
            + a14 * a22 * a31 * a43
            + a14 * a23 * a32 * a41
            - a11 * a22 * a34 * a43
            - a11 * a23 * a32 * a44
            - a11 * a24 * a33 * a42
            - a12 * a21 * a33 * a44
            - a12 * a23 * a34 * a41
            - a12 * a24 * a31 * a43
            - a13 * a21 * a34 * a42
            - a13 * a22 * a31 * a44
            - a13 * a24 * a32 * a41
            - a14 * a21 * a32 * a43
            - a14 * a22 * a33 * a41
            - a14 * a23 * a31 * a42)

            return null if 0.0001 > det > -0.0001

            b11 = ((a22 * a33 * a44) + (a23 * a34 * a42) + (a24 * a32 * a43) - (a22 * a34 * a43) - (a23 * a32 * a44) - (a24 * a33 * a42)) / det
            b12 = ((a12 * a34 * a43) + (a13 * a32 * a44) + (a14 * a33 * a42) - (a12 * a33 * a44) - (a13 * a34 * a42) - (a14 * a32 * a43)) / det
            b13 = ((a12 * a23 * a44) + (a13 * a24 * a42) + (a14 * a22 * a43) - (a12 * a24 * a43) - (a13 * a22 * a44) - (a14 * a23 * a42)) / det
            b14 = ((a12 * a24 * a33) + (a13 * a22 * a34) + (a14 * a23 * a32) - (a12 * a23 * a34) - (a13 * a24 * a32) - (a14 * a22 * a33)) / det

            b21 = ((a21 * a34 * a43) + (a23 * a31 * a44) + (a24 * a33 * a41) - (a21 * a33 * a44) - (a23 * a34 * a41) - (a24 * a31 * a43)) / det
            b22 = ((a11 * a33 * a44) + (a13 * a34 * a41) + (a14 * a31 * a43) - (a11 * a34 * a43) - (a13 * a31 * a44) - (a14 * a33 * a41)) / det
            b23 = ((a11 * a24 * a43) + (a13 * a21 * a44) + (a14 * a23 * a41) - (a11 * a23 * a44) - (a13 * a24 * a41) - (a14 * a21 * a43)) / det
            b24 = ((a11 * a23 * a34) + (a13 * a24 * a31) + (a14 * a21 * a33) - (a11 * a24 * a33) - (a13 * a21 * a34) - (a14 * a23 * a31)) / det

            b31 = ((a21 * a32 * a44) + (a22 * a34 * a41) + (a24 * a31 * a42) - (a21 * a34 * a42) - (a22 * a31 * a44) - (a24 * a32 * a41)) / det
            b32 = ((a11 * a34 * a42) + (a12 * a31 * a44) + (a14 * a32 * a41) - (a11 * a32 * a44) - (a12 * a34 * a41) - (a14 * a31 * a42)) / det
            b33 = ((a11 * a22 * a44) + (a12 * a24 * a41) + (a14 * a21 * a42) - (a11 * a24 * a42) - (a12 * a21 * a44) - (a14 * a22 * a41)) / det
            b34 = ((a11 * a24 * a32) + (a12 * a21 * a34) + (a14 * a22 * a31) - (a11 * a22 * a34) - (a12 * a24 * a31) - (a14 * a21 * a32)) / det

            b41 = ((a21 * a33 * a42) + (a22 * a31 * a43) + (a23 * a32 * a41) - (a21 * a32 * a43) - (a22 * a33 * a41) - (a23 * a31 * a42)) / det
            b42 = ((a11 * a32 * a43) + (a12 * a33 * a41) + (a13 * a31 * a42) - (a11 * a33 * a42) - (a12 * a31 * a43) - (a13 * a32 * a41)) / det
            b43 = ((a11 * a23 * a42) + (a12 * a21 * a43) + (a13 * a22 * a41) - (a11 * a22 * a43) - (a12 * a23 * a41) - (a13 * a21 * a42)) / det
            b44 = ((a11 * a22 * a33) + (a12 * a23 * a31) + (a13 * a21 * a32) - (a11 * a23 * a32) - (a12 * a21 * a33) - (a13 * a22 * a31)) / det

            oe[0] = b11; oe[4] = b12; oe[8]  = b13; oe[12] = b14;
            oe[1] = b21; oe[5] = b22; oe[9]  = b23; oe[13] = b24;
            oe[2] = b31; oe[6] = b32; oe[10] = b33; oe[14] = b34;
            oe[3] = b41; oe[7] = b42; oe[11] = b43; oe[15] = b44;

            return out


        ###*
            Copy from `m`
            @param {Matrix4} m
        ###
        copy: (m) ->

            te = @elements
            me = m.elements

            te[0] = me[0]; te[4] = me[4]; te[8]  = me[8];  te[12] = me[12];
            te[1] = me[1]; te[5] = me[5]; te[9]  = me[9];  te[13] = me[13];
            te[2] = me[2]; te[6] = me[6]; te[10] = me[10]; te[14] = me[14];
            te[3] = me[3]; te[7] = me[7]; te[11] = me[11]; te[15] = me[15];

            return @

        makeFrustum: (left, right, bottom, top, near, far) ->

            te = @elements
            vw = right - left
            vh = top - bottom

            x = 2 * near / vw
            y = 2 * near / vh

            a = (right + left) / (right - left)
            b = (top + bottom) / (top - bottom)
            c = - (far + near) / (far - near)
            d = - (2 * near * far) / (far - near)


            # W値用の値を算出
            #
            # Z座標は、ニアクリップ面では z/w = -1、
            # ファークリップ面では z/w = 1 になるように
            # バイアスされ、スケーリングされる。
            te[0]  = x; te[4] = 0; te[8]  =  a; te[12] = 0;
            te[1]  = 0; te[5] = y; te[9]  =  b; te[13] = 0;
            te[2]  = 0; te[6] = 0; te[10] =  c; te[14] = d;
            te[3]  = 0; te[7] = 0; te[11] = -1; te[15] = 0;

            return @


        perspectiveLH: (fov, aspect, near, far) ->
            tmp = Matrix4.perspectiveLH(fov, aspect, near, far)
            @copy tmp

        @perspectiveLH: (fov, aspect, near, far) ->

            tmp = new Matrix4
            te  = tmp.elements

            ymax = near * tan(fov * DEG_TO_RAD * 0.5)
            ymin = -ymax
            xmin = ymin * aspect
            xmax = ymax * aspect

            return tmp.makeFrustum xmin, xmax, ymin, ymax, near, far

        multiply: (A) ->
            tmp = Matrix4.multiply(@, A)
            @copy tmp

            return @


        # multiplication
        # ABふたつの行列の掛け算した結果をthisに保存
        @multiply: (A, B) ->

            ae = A.elements
            be = B.elements

            A11 = ae[0]; A12 = ae[4]; A13 = ae[8];  A14 = ae[12];
            A21 = ae[1]; A22 = ae[5]; A23 = ae[9];  A24 = ae[13];
            A31 = ae[2]; A32 = ae[6]; A33 = ae[10]; A34 = ae[14];
            A41 = ae[3]; A42 = ae[7]; A43 = ae[11]; A44 = ae[15];

            B11 = be[0]; B12 = be[4]; B13 = be[8];  B14 = be[12];
            B21 = be[1]; B22 = be[5]; B23 = be[9];  B24 = be[13];
            B31 = be[2]; B32 = be[6]; B33 = be[10]; B34 = be[14];
            B41 = be[3]; B42 = be[7]; B43 = be[11]; B44 = be[15];

            tmp = new Matrix4
            te  = tmp.elements

            te[0]  = A11 * B11 + A12 * B21 + A13 * B31 + A14 * B41
            te[4]  = A11 * B12 + A12 * B22 + A13 * B32 + A14 * B42
            te[8]  = A11 * B13 + A12 * B23 + A13 * B33 + A14 * B43
            te[12] = A11 * B14 + A12 * B24 + A13 * B34 + A14 * B44

            te[1]  = A21 * B11 + A22 * B21 + A23 * B31 + A24 * B41
            te[5]  = A21 * B12 + A22 * B22 + A23 * B32 + A24 * B42
            te[9]  = A21 * B13 + A22 * B23 + A23 * B33 + A24 * B43
            te[13] = A21 * B14 + A22 * B24 + A23 * B34 + A24 * B44

            te[2]  = A31 * B11 + A32 * B21 + A33 * B31 + A34 * B41
            te[6]  = A31 * B12 + A32 * B22 + A33 * B32 + A34 * B42
            te[10] = A31 * B13 + A32 * B23 + A33 * B33 + A34 * B43
            te[14] = A31 * B14 + A32 * B24 + A33 * B34 + A34 * B44

            te[3]  = A41 * B11 + A42 * B21 + A43 * B31 + A44 * B41
            te[7]  = A41 * B12 + A42 * B22 + A43 * B32 + A44 * B42
            te[11] = A41 * B13 + A42 * B23 + A43 * B33 + A44 * B43
            te[15] = A41 * B14 + A42 * B24 + A43 * B34 + A44 * B44

            return tmp

        ###*
            Multiply Matrices
            A, Bふたつの行列の掛け算した結果をthisに保存
            @param {Matrix4} A.
            @param {Matrix4} B.
        ###
        multiplyMatrices: (A, B) ->
            tmp = Matrix4.multiply A, B
            @copy tmp

            return @

        ###*
            @param {Vector3} v
        ###
        translate: (v) ->

            te = @elements
            x = v.x
            y = v.y
            z = v.z

            te[0] = 1; te[4] = 0; te[8]  = 0; te[12] = x;
            te[1] = 0; te[5] = 1; te[9]  = 0; te[13] = y;
            te[2] = 0; te[6] = 0; te[10] = 1; te[14] = z;
            te[3] = 0; te[7] = 0; te[11] = 0; te[15] = 1;

            return @

        ###*
            Scale matrix
            @param {Vector3} v
        ###
        scale: (v) ->
            te = @elements
            x = v.x
            y = v.y
            z = v.z

            te[0] = x; te[4] = 0; te[8]  = 0; te[12] = 0;
            te[1] = 0; te[5] = y; te[9]  = 0; te[13] = 0;
            te[2] = 0; te[6] = 0; te[10] = z; te[14] = 0;
            te[3] = 0; te[7] = 0; te[11] = 0; te[15] = 1;

            return @

        ###*
            @param {Vector3} eye
            @param {Vector3} target
            @param {Vector3} up
        ###
        lookAt: do ->
            #カメラに対してのX, Y, Z軸をそれぞれ定義
            x = new Vector3
            y = new Vector3
            z = new Vector3

            return (eye, target, up) ->

                te = @elements

                z.subVectors(eye, target).normalize()
                x.crossVectors(z, up).normalize()
                y.crossVectors(x, z).normalize()

                tx = eye.dot x
                ty = eye.dot y
                tz = eye.dot z

                te[0] = x.x; te[4] = x.y; te[8]  = x.z; te[12] = -tx;
                te[1] = y.x; te[5] = y.y; te[9]  = y.z; te[13] = -ty;
                te[2] = z.x; te[6] = z.y; te[10] = z.z; te[14] = -tz;

                return @

        ###*
            @param {number} r Rotate X
        ###
        rotationX: (r) ->

            # OpenGLのX軸による回転行列
            # |1       0      0  0|
            # |0  cos(r) -sin(r) 0|
            # |0  sin(r)  cos(r) 0|
            # |0       0      0  1|

            te = @elements
            c = cos r
            s = sin r

            te[0] = 1; te[4] = 0; te[8]  =  0; te[12] = 0;
            te[1] = 0; te[5] = c; te[9]  = -s; te[13] = 0;
            te[2] = 0; te[6] = s; te[10] =  c; te[14] = 0;
            te[3] = 0; te[7] = 0; te[11] =  0; te[15] = 1;

            return @

        ###*
            @param {number} r Rotate Y
        ###
        rotationY: (r) ->

            # OpenGLのY軸による回転行列
            # | cos(r)  0  sin(r)  0|
            # |      0  1       0  0|
            # |-sin(r)  0  cos(r)  0|
            # |      0  0       0  1|
            
            te = @elements
            c = cos r
            s = sin r

            te[0] =  c; te[4] = 0; te[8]  = s; te[12] = 0;
            te[1] =  0; te[5] = 1; te[9]  = 0; te[13] = 0;
            te[2] = -s; te[6] = 0; te[10] = c; te[14] = 0;
            te[3] =  0; te[7] = 0; te[11] = 0; te[15] = 1;

            return @

        ###*
            @param {number} r Rotate Z
        ###
        rotationZ: (r) ->

            # OpenGLのZ軸による回転行列
            # | cos(r) -sin(r)  0  0|
            # | sin(r)  cos(r)  0  0|
            # |      0      0   1  0|
            # |      0      0   0  1|

            te = @elements
            c = cos r
            s = sin r

            te[0] = c; te[4] = -s; te[8]  = 0; te[12] = 0;
            te[1] = s; te[5] =  c; te[9]  = 0; te[13] = 0;
            te[2] = 0; te[6] =  0; te[10] = 1; te[14] = 0;
            te[3] = 0; te[7] =  0; te[11] = 0; te[15] = 1;

            return @

        clone: ->
            tmp = new Matrix4
            tmp.copy @
            return tmp

# -------------------------------------------------------------------------------

    class Object3D
        constructor: ->
            @parent = null
            @children = []
            @vertices = []
            @position = new Vector3
            @rotation = new Vector3
            @scale = new Vector3 1, 1, 1
            @up    = new Vector3 0, 1, 0

            @matrixScale = new Matrix4
            @matrixTranslate = new Matrix4
            @matrixRotation = new Matrix4
            @matrix = new Matrix4
            @matrixWorld = new Matrix4

            @updateMatrix()

        updateScale: do ->
            sm = new Matrix4

            return ->
                return false if @prevScale and @scale.equal(@prevScale)

                @prevScale = @scale.clone()
                @matrixScale = sm.clone().scale(@scale)

                return true

        updateTranslate: do ->
            tm = new Matrix4

            return ->
                return false if @prevPosition and @position.equal(@prevPosition)

                @prevPosition = @position.clone()
                @matrixTranslate = tm.clone().translate(@position)

                return true

        updateRotation: do ->
            rmx = new Matrix4
            rmy = new Matrix4
            rmz = new Matrix4

            return ->

                return false if @prevRotation and @rotation.equal(@prevRotation)

                x = @rotation.x * DEG_TO_RAD
                y = @rotation.y * DEG_TO_RAD
                z = @rotation.z * DEG_TO_RAD

                tmp = new Matrix4
                rmx.rotationX x
                rmy.rotationY y
                rmz.rotationZ z

                tmp.multiplyMatrices rmx, rmy
                tmp.multiply rmz

                @prevRotation = @rotation.clone()
                @matrixRotation = tmp

                return true

        updateMatrix: ->

            updatedScale     = @updateScale()
            updatedRotation  = @updateRotation()
            updatedTranslate = @updateTranslate()

            if updatedRotation or updatedTranslate or updatedScale
                @matrix.multiplyMatrices @matrixTranslate, @matrixRotation
                @matrix.multiply @matrixScale
                @needUpdateMatrix = true

            else
                @needUpdateMatrix = false

            c.updateMatrix() for c in @children
            return

        updateMatrixWorld: (force) ->

            if not @parent
                @matrixWorld.copy @matrix
            else
                if force or @parent.needUpdateMatrix or @needUpdateMatrix or @parent.needUpdateMatrixWorld
                    @matrixWorld.multiplyMatrices @parent.matrixWorld, @matrix
                    @needUpdateMatrixWorld = true
                else
                    @needUpdateMatrixWorld = false

            c.updateMatrixWorld() for c in @children
            return

        getVerticesByProjectionMatrix: (m) ->

            ret = []

            for v in @vertices
                wm = Matrix4.multiply m, @matrixWorld
                tmp = []
                outside = v.clone().applyProjection(wm, tmp)

                continue if not outside

                ret = ret.concat(tmp[0].toArray().concat(tmp[1]))

            return ret

        add: (object) ->
            return null if @ is object

            object.parent?.remove object

            @children.push object
            object.parent = @

        remove: (object) ->
            return null if @ is object

            index = @children.indexOf object

            return null if index is -1

            ret = @children.splice index, 1

# -------------------------------------------------------------------------------

    ###*
        Camera class
        @constructor
        @param {number} fov Field of view.
        @param {number} aspect Aspect ratio.
        @param {number} near Near clip.
        @param {number} far far clip.
        @param {Vector3} position Position vector.
    ###
    class Camera extends Object3D
        constructor: (@fov, @aspect, @near, @far, @position = new Vector3(0, 0, 20)) ->
            super

            @lookAtMatrix     = new Matrix4
            @viewMatrix       = new Matrix4
            @projectionMatrix = new Matrix4

        getProjectionMatrix: ->
            return Matrix4.multiply @projectionMatrix, @viewMatrix

        updateProjectionMatrix: ->
            @updateLookAt()
            @projectionMatrix.perspectiveLH(@fov, @aspect, @near, @far)

        updateLookAt: do ->
            lm = new Matrix4
            previous = null

            return ->
                previous = @position.clone() if not previous

                return if @position.equal previous

                if not @lookAtLock
                    @target.add(@position.clone().sub previous)

                @lookAt()
                previous = @position.clone()

        lookAt: do ->
            m1 = new Matrix4

            return (target) ->
                @target = target or @target or new Vector3
                m1.lookAt @position, @target, @up
                @viewMatrix.copy m1

# -------------------------------------------------------------------------------

    ###*
        Line class
            Line -> Object3D
        @constructor
        @param {Vector3} vec1
        @param {Vector3} vec2
    ###
    class Line extends Object3D
        constructor: (x1, y1, z1, x2, y2, z2, @color = new Color(255, 255, 255, 1)) ->
            super
            @type = 'line'

            @vertices.push new Vector3 x1, y1, z1
            @vertices.push new Vector3 x2, y2, z2

# -------------------------------------------------------------------------------

    ###*
        Triangle class
            Triangle -> Object3D
        @constructor
        @param {Array} vertecies
        @param {Texture} texture
    ###
    class Triangle extends Object3D
        constructor: (vertices, material) ->
            super
            @type = 'triangle'

            if material instanceof Texture
                if {}.toString.call(material.uv_data) is '[object String]'
                    @color = new Color(0, 0, 0, 0)
                    img = new Image
                    img.onload = =>
                        material.uv_data = img
                        @setTexture material
                        img = null

                    img.src = material.uv_data

                else
                    @setTexture material

            else if material instanceof Color
                @color = material

            @vertices = []
            for v, i in vertices by 3
                vec3 = new Vector3 vertices[i + 0], vertices[i + 1], vertices[i + 2]
                @vertices.push vec3

        getNormal: do ->
            a = new Vector3
            b = new Vector3

            return ->
                a.subVectors(@vertices[1], @vertices[0])
                b.subVectors(@vertices[2], @vertices[0])
                
                return a.clone().cross(b).applyMatrix4(@matrixWorld).normalize()

        getCenter: do ->
            result = new Vector3

            return ->
                result.addVectors(@vertices[1], @vertices[0])
                ret = result.clone().add(@vertices[2])
                return ret.multiplyScalar(1 / 3)


        setTexture: (texture) ->
            return false if not texture instanceof Texture
            @texture = texture
        
# -------------------------------------------------------------------------------

    ###*
        Face class
            Face -> Object3D
        @constructor
        @param {number} x1
        @param {number} y1
        @param {number} x2
        @param {number} y2
        @param {Texture} texture1
        @param {Texture} texture2
    ###
    class Face2 extends Object3D
        constructor: (width, height, divW, divH, image1, image2) ->
            super
            @type = 'face'

            hw = width  * 0.5
            hh = height * 0.5
            partW = width / divW
            partH = -height / divH

            for wi in [0...divH]
                for hi in [0...divW]
                    x1 = ((wi + 0) * partW) - hw
                    y1 = ((hi + 0) * partH) + hh
                    x2 = ((wi + 0) * partW) - hw
                    y2 = ((hi + 1) * partH) + hh
                    x3 = ((wi + 1) * partW) - hw
                    y3 = ((hi + 1) * partH) + hh
                    x4 = ((wi + 1) * partW) - hw
                    y4 = ((hi + 0) * partH) + hh

                    texture1 = null
                    texture2 = null

                    if image1 instanceof Color
                        texture1 = image1
                        texture2 = image2

                    else
                        uv_x1 = ((wi + 0) *  partW) / width
                        uv_y1 = ((hi + 0) * -partH) / height
                        uv_x2 = ((wi + 0) *  partW) / width
                        uv_y2 = ((hi + 1) * -partH) / height
                        uv_x3 = ((wi + 1) *  partW) / width
                        uv_y3 = ((hi + 1) * -partH) / height
                        uv_x4 = ((wi + 1) *  partW) / width
                        uv_y4 = ((hi + 0) * -partH) / height

                        texture1 = new Texture(image1, [
                            uv_x1, uv_y1
                            uv_x2, uv_y2
                            uv_x4, uv_y4
                        ])

                        texture2 = new Texture(image2, [
                            uv_x2, uv_y2
                            uv_x3, uv_y3
                            uv_x4, uv_y4
                        ])

                    triangle1 = new Triangle([
                        x1, y1, 0
                        x2, y2, 0
                        x4, y4, 0
                    ], texture1)

                    triangle2 = new Triangle([
                        x2, y2, 0
                        x3, y3, 0
                        x4, y4, 0
                    ], texture2)

                    @add triangle1
                    @add triangle2

        setTexture: (texture, targetFace) ->
            #TODO will be implement this method.
            return if not (texture instanceof Color or texture instanceof Texture)


    ###*
        Face class
            Face -> Object3D
        @constructor
        @param {number} x1
        @param {number} y1
        @param {number} x2
        @param {number} y2
        @param {Texture} texture1
        @param {Texture} texture2
    ###
    class Face extends Object3D
        constructor: (x1, y1, x2, y2, texture1, texture2) ->
            super
            @type = 'face'

            triangle1 = new Triangle([
                x1, y1, 0
                x1, y2, 0
                x2, y1, 0
            ], texture1)

            @add triangle1

            triangle2 = new Triangle([
                x1, y2, 0
                x2, y2, 0
                x2, y1, 0
            ], texture2)

            @add triangle2

# -------------------------------------------------------------------------------

    ###*
        Plate class
            Plate -> Object3D
        @constructor
        @param {number} width
        @param {number} height
        @param {Texture} texture1
        @param {Texture} texture2
    ###
    class Plate extends Object3D
        constructor: (width, height, sx, sy, image1, image2, image3 = image1, image4 = image2) ->
            super
            @type = 'plate'

            face1 = new Face2 width, height, sx, sy, image1, image2
            face2 = new Face2 width, height, sx, sy, image3, image4
            face2.rotation.y = 180

            @add face1
            @add face2

# -------------------------------------------------------------------------------

    ###*
        Cube class
        @constructor
        @param {number} width.
        @param {number} height.
        @param {number} p profound.
        @param {number} sx divide as x axis.
        @param {number} sy divide as y axis.
        @param {number} sz divide as z axis.
        @param {<Array.<Texture>} materials texture materials.
    ###
    class Cube extends Object3D
        constructor: (width, height, p, sx = 1, sy = 1, sz = 1, materials) ->
            super
            @type = 'cube'

            #width *= 0.5
            #height *= 0.5
            #p *= 0.5

            hw = width  * 0.5
            hh = height * 0.5
            hp = p * 0.5

            #TOP
            topFace = new Face2 width, p, sx, sz, materials[0], materials[1]
            topFace.rotation.x = -90
            topFace.position.y = hh

            #BOTTOM
            bottomFace = new Face2 width, p, sx, sz, materials[2], materials[3]
            bottomFace.rotation.x = 90
            bottomFace.position.y = -hh

            ##FRONT
            frontFace = new Face2 width, height, sx, sy, materials[4], materials[5]
            frontFace.position.z = hp

            ##BACK
            backFace = new Face2 width, height, sx, sy, materials[6], materials[7]
            backFace.rotation.y = 180
            backFace.position.z = -hp

            ##LEFT
            leftFace = new Face2 p, height, sz, sy, materials[8], materials[9]
            leftFace.rotation.y = -90
            leftFace.position.x = -hw

            ##RIGHT
            rightFace = new Face2 p, height, sz, sy, materials[10], materials[11]
            rightFace.rotation.y = 90
            rightFace.position.x = hw

            @add rightFace
            @add leftFace
            @add backFace
            @add frontFace
            @add bottomFace
            @add topFace

# -------------------------------------------------------------------------------

    class Texture
        constructor: (@uv_data, @uv_list) ->

# -------------------------------------------------------------------------------

    class Particle extends Object3D
        constructor: (vec, @size = 10, @color = new Color(255, 255, 255, 1)) ->
            super
            @vertices.push vec
            @type = 'particle'

# -------------------------------------------------------------------------------

    class Color
        constructor: (r = 0, g = 0, b = 0, @a = 1) ->
            d = 1 / 255
            @r = r * d
            @g = g * d
            @b = b * d

        copy: (c) ->
            @r = c.r
            @g = c.g
            @b = c.b
            @a = c.a
            return @

        add: (c) ->
            @r = min((@r + c.r), 1)
            @g = min((@g + c.g), 1)
            @b = min((@b + c.b), 1)
            @a = min((@a + c.a), 1)
            return @

        sub: (c) ->
            @r = max((@r - c.r), 0)
            @g = max((@g - c.g), 0)
            @b = max((@b - c.b), 0)
            @a = max((@a - c.a), 0)
            return @

        multiplyScalar: (s) ->
            @r *= s
            @g *= s
            @b *= s
            @a *= s
            return @

        clone: ->
            tmp = new Color
            tmp.copy @
            return tmp

        toString: ->
            r = ~~min(@r * 255, 255)
            g = ~~min(@g * 255, 255)
            b = ~~min(@b * 255, 255)
            a = min(@a, 1)

            return "rgba(#{r}, #{g}, #{b}, #{a})"

# -------------------------------------------------------------------------------

    class Light extends Object3D
        constructor: (@strength) ->
            super

# -------------------------------------------------------------------------------

    class AmbientLight extends Light
        constructor: (strength) ->
            super

# -------------------------------------------------------------------------------

    class PointLight extends Light
        constructor: (strength, attenuation, position) ->
            super
            @position = position
            @attenuation = attenuation

# -------------------------------------------------------------------------------

    class DirectionalLight extends Light
        constructor: (strength, @direction) ->
            super
            @direction.normalize()

# -------------------------------------------------------------------------------

    class Scene
        constructor: ->
            @lights    = []
            @materials = []

        add: (material) ->
            if material instanceof Light
                @lights.push material

            else if material instanceof Object3D
                @materials.push material

        update: ->
            for m in @materials
                m.updateMatrix()
                m.updateMatrixWorld()

            for l in @lights
                if l instanceof PointLight
                    l.updateMatrix()
                    l.updateMatrixWorld()

# -------------------------------------------------------------------------------

    class Renderer
        constructor: (@cv, @clearColor = '#fff') ->
            @_prerenderCv = doc.createElement 'canvas'
            @_prerenderG  = @_prerenderCv.getContext '2d'

            @_colorCv     = doc.createElement 'canvas'
            @_colorG      = @_colorCv.getContext '2d'

            @_colorCv.width = @_colorCv.height = 1

            @g = cv.getContext '2d'
            @w = @_prerenderCv.width  = cv.width
            @h = @_prerenderCv.height = cv.height

            @fog      = true
            @lighting = true
            @fogColor = @clearColor
            @fogStart = 200
            @fogEnd   = 1000

            @wireframeColor =  'rgba(255, 255, 255, 0.5)'

        render: (scene, camera) ->
            camera.updateMatrix()
            camera.updateMatrixWorld()
            camera.updateProjectionMatrix()
            matProj = camera.getProjectionMatrix()

            @g.beginPath()
            @g.fillStyle = @clearColor
            @g.fillRect 0, 0, @w, @h

            scene.update()
            lights    = scene.lights
            vertecies = @getTransformedPoint matProj, scene.materials

            @drawMaterials @g, vertecies, lights, @w, @h

        drawMaterials: (g, vertecies, lights, vw, vh) ->

            fogColor = @fogColor
            fogStart = @fogStart
            fogEnd   = @fogEnd
            fog      = @fog
            lighting = @lighting

            pcv = @_prerenderCv
            pg  = @_prerenderG
            ccv = @_colorCv
            cg  = @_colorG

            wireframeColor = @wireframeColor

            for v, i in vertecies

                #save
                prevFillStyle     = g.fillStyle
                prevStrokeStyle   = g.strokeStyle
                prevAlpha         = g.globalAlpha
                prevPgFillStyle   = pg.fillStyle
                prevPgStrokeStyle = pg.strokeStyle
                prevPgAlpha       = pg.globalAlpha
                prevCgFillStyle   = cg.fillStyle
                prevCgStrokeStyle = cg.strokeStyle
                prevCgAlpha       = cg.globalAlpha

                vertexList = v.vertecies
                z = v.getZPosition()
                fogStrength = 0
                normal = v.normal

                hvw = vw * 0.5
                hvh = vh * 0.5

                x1 = (vertexList[0] *  hvw) + hvw
                y1 = (vertexList[1] * -hvh) + hvh
                z1 =  vertexList[2]
                w1 =  vertexList[3]
                x2 = (vertexList[4] *  hvw) + hvw
                y2 = (vertexList[5] * -hvh) + hvh
                z2 =  vertexList[6]
                w2 =  vertexList[7]
                x3 = (vertexList[8] *  hvw) + hvw
                y3 = (vertexList[9] * -hvh) + hvh
                z3 =  vertexList[10]
                w3 =  vertexList[11]

                if v.type is 'line'
                    if fog
                        fogStrength = ((fogEnd - z) / (fogEnd - fogStart))
                        fogStrength = 0 if fogStrength < 0
                        g.globalAlpha = fogStrength

                    g.beginPath()
                    g.moveTo x1, y1
                    g.lineTo x2, y2
                    g.closePath()
                    g.strokeStyle = v.color.toString()
                    g.stroke()

                else if v.type is 'particle'
                    if fog
                        fogStrength = ((fogEnd - z) / (fogEnd - fogStart))
                        fogStrength = 0 if fogStrength < 0
                        g.globalAlpha = fogStrength

                    g.beginPath()
                    g.fillStyle = v.color.toString()
                    g.arc x1, y1, v.size / w1, 0, PI * 2, true
                    g.fill()

                else if v.type is 'triangle'

                    img = null

                    # 裏面カリング
                    # 頂点を結ぶ順が時計回りの場合は「裏面」になり、その場合は描画をスキップ
                    # 裏面かどうかの判定は外積を利用する
                    # 判定は、p1, p2, p3の3点から、p1->p2, p1->p3のベクトルとの外積を利用する。

                    __Ax = vertexList[4] - vertexList[0]; __Ay = vertexList[5] - vertexList[1];
                    __Bx = vertexList[8] - vertexList[0]; __By = vertexList[9] - vertexList[1];

                    continue if (__Ax * __By) - (__Ay * __Bx) < 0

                    lightingColor = new Color 0, 0, 0, 1
                    _Ax = x2 - x1; _Ay = y2 - y1; _Az = z2 - z1
                    _Bx = x3 - x1; _By = y3 - y1; _Bz = z3 - z1

                    if lighting
                        strength = 0

                        for l in lights
                            if l instanceof AmbientLight
                                strength += l.strength

                            else if l instanceof DirectionalLight
                                L = l.direction
                                N = normal
                                factor = N.dot(L)
                                strength += l.strength * factor if factor > 0

                            else if l instanceof PointLight
                                distance = l.position.clone().sub(v.center).norm()
                                L = l.position.clone().normalize()
                                N = normal
                                factor = N.dot(L)

                                if l.attenuation < distance
                                    str = 0
                                else
                                    str = (l.attenuation - distance) / l.attenuation

                                if factor > 0 and str > 0
                                    strength += l.strength * str * factor
                                
                        lightingColor.a -= strength

                    if v.uvData
                        img    = v.uvData
                        uvList = v.uvList
                        pcv.width  = width  = img.width  or img.videoWidth  or 0
                        pcv.height = height = img.height or img.videoHeight or 0

                        # 変換前のベクトル成分を計算
                        Ax = (uvList[2] - uvList[0]) * width
                        Ay = (uvList[3] - uvList[1]) * height
                        Bx = (uvList[4] - uvList[0]) * width
                        By = (uvList[5] - uvList[1]) * height

                        # move position from A(Ax, Ay) to _A(_Ax, _Ay)
                        # move position from B(Ax, Ay) to _B(_Bx, _By)
                        # A,Bのベクトルを、_A,_Bのベクトルに変換することが目的。
                        # 変換を達成するには、a, b, c, dそれぞれの係数を導き出す必要がある。
                        #
                        #    ↓まずは公式。アフィン変換の移動以外を考える。
                        #
                        # _Ax = a * Ax + c * Ay
                        # _Ay = b * Ax + d * Ay
                        # _Bx = a * Bx + c * By
                        # _By = b * Bx + d * By
                        #
                        #    ↓上記の公式を行列の計算で表すと以下に。
                        #
                        # |_Ax| = |Ax Ay||a|
                        # |_Bx| = |Bx By||c|
                        #
                        #    ↓a, cについて求めたいのだから、左に掛けているものを「1」にする必要がある。
                        #    　行列を1にするには、逆行列を左から掛ければいいので、両辺に逆行列を掛ける。（^-1は逆行列の意味）
                        #
                        # |Ax Ay|^-1 |_Ax| = |a|
                        # |Bx By|    |_Bx| = |c|

                        # 上記の
                        # |Ax Ay|
                        # |Bx By|
                        # を生成
                        m = new Matrix2(Ax, Ay, Bx, By)
                        me = m.elements

                        # 逆行列を取得
                        # 上記の
                        # |Ax Ay|^-1
                        # |Bx By|
                        # を生成
                        mi = m.getInvert()

                        # 逆行列が存在しない場合はスキップ
                        continue if not mi

                        mie = mi.elements

                        a = mie[0] * _Ax + mie[2] * _Bx
                        c = mie[1] * _Ax + mie[3] * _Bx
                        b = mie[0] * _Ay + mie[2] * _By
                        d = mie[1] * _Ay + mie[3] * _By

                        # 各頂点座標を元に三角形を作り、それでクリッピング
                        g.save()
                        #cg.save()

                        pg.drawImage(img, 0, 0)


                        if lightingColor.a > 0
                            cg.fillStyle = lightingColor.toString()
                            cg.fillRect 0, 0, 1, 1

                        if fog
                            fogStrength = 1 - ((fogEnd - z) / (fogEnd - fogStart))

                            if fogStrength > 0
                                cg.globalAlpha = fogStrength
                                cg.fillStyle   = fogColor
                                cg.fillRect 0, 0, 1, 1

                        data = cg.getImageData(0, 0, 1, 1).data

                        _r = data[0]
                        _g = data[1]
                        _b = data[2]
                        _a = data[3] / 255

                        pg.fillStyle = (new Color(_r, _g, _b, _a)).toString()
                        pg.fillRect 0, 0, width , height

                        g.beginPath()
                        g.moveTo(x1, y1)
                        g.lineTo(x2, y2)
                        g.lineTo(x3, y3)
                        g.closePath()

                        if @wireframe
                            g.strokeStyle = wireframeColor
                            g.stroke()

                        g.clip()

                        g.setTransform(a, b, c, d,
                            x1 - (a * uvList[0] * width + c * uvList[1] * height),
                            y1 - (b * uvList[0] * width + d * uvList[1] * height))

                        g.drawImage pcv, 0, 0

                        cg.clearRect 0, 0, 1, 1
                        #cg.restore()
                        g.restore()

                    else if v.color
                        cg.fillStyle = v.color.toString()
                        cg.fillRect 0, 0, 1, 1

                        if lightingColor.a > 0
                            cg.fillStyle = lightingColor.toString()
                            cg.fillRect 0, 0, 1, 1

                        if fog
                            fogStrength = 1 - ((fogEnd - z) / (fogEnd - fogStart))

                            if fogStrength > 0
                                cg.globalAlpha = fogStrength
                                cg.fillStyle   = fogColor
                                cg.fillRect 0, 0, 1, 1

                        data = cg.getImageData(0, 0, 1, 1).data

                        _r = data[0]
                        _g = data[1]
                        _b = data[2]
                        _a = data[3] / 255

                        g.beginPath()
                        g.moveTo(x1, y1)
                        g.lineTo(x2, y2)
                        g.lineTo(x3, y3)
                        g.closePath()

                        g.strokeStyle = g.fillStyle = (new Color(_r, _g, _b, _a)).toString()
                        g.fill()
                        g.stroke()

                        if @wireframe
                            g.strokeStyle = wireframeColor
                            g.stroke()

                        cg.clearRect 0, 0, 1, 1

                g.fillStyle    = prevFillStyle
                g.strokeStyle  = prevStrokeStyle
                g.globalAlpha  = prevAlpha
                pg.fillStyle   = prevPgFillStyle
                pg.strokeStyle = prevPgStrokeStyle
                pg.globalAlpha = prevPgAlpha
                cg.fillStyle   = prevCgFillStyle
                cg.strokeStyle = prevCgStrokeStyle
                cg.globalAlpha = prevCgAlpha

        getTransformedPoint: (mat, materials) ->

            results = []

            for m in materials
                if m instanceof Triangle
                    vertecies = m.getVerticesByProjectionMatrix(mat)

                    vertex = new Vertex vertecies
                    vertex.type = m.type

                    continue if vertex.getZPosition() < 0

                    if m.texture
                        vertex.uvData = m.texture.uv_data
                        vertex.uvList = m.texture.uv_list
                    else if m.color
                        vertex.color = m.color

                    vertex.normal = m.getNormal()
                    vertex.center = m.getCenter()
                    results.push vertex

                else if m instanceof Line
                    vertecies = m.getVerticesByProjectionMatrix(mat)
                    vertex = new Vertex vertecies
                    vertex.color = m.color
                    vertex.type = m.type

                    continue if vertex.getZPosition() < 0

                    results.push vertex

                else if m instanceof Particle
                    vertecies = m.getVerticesByProjectionMatrix(mat)
                    vertex = new Vertex vertecies
                    vertex.color = m.color
                    vertex.size  = m.size
                    vertex.type = m.type

                    continue if vertex.getZPosition() < 0

                    results.push vertex

                else
                    tmp = @getTransformedPoint mat, m.children
                    results = results.concat tmp

            results.sort (a, b) ->
                 b.getZPosition() - a.getZPosition()

            return results

# ---------------------------------------------------------------------

    class Quaternion
        constructor: (@t = 0, @v) ->

        set: (@t, @v) ->

        multiply: (A) ->
            return Quaternion.multiply @, A

        @multiply: (A, B) ->

            # Quaternionの掛け算の公式は以下。
            # ・は内積、×は外積、U, Vはともにベクトル。
            # ;の左が実部、右が虚部。
            # A = (a; U) 
            # B = (b; V) 
            # AB = (ab - U・V; aV + bU + U×V)

            Av = A.v
            Bv = B.v

            # 実部の計算
            d1 =  A.t * B.t
            d2 = -Av.x * Bv.x
            d3 = -Av.y * Bv.y
            d4 = -Av.z * Bv.z
            t = parseFloat((d1 + d2 + d3 + d4).toFixed(5))

            # 虚部xの計算
            d1 = (A.t * Bv.x) + (B.t * Av.x)
            d2 = (Av.y * Bv.z) - (Av.z * Bv.y)
            x = parseFloat((d1 + d2).toFixed(5))

            # 虚部yの計算
            d1 = (A.t * Bv.y) + (B.t * Av.y)
            d2 = (Av.z * Bv.x) - (Av.x * Bv.z)
            y = parseFloat((d1 + d2).toFixed(5))

            # 虚部zの計算
            d1 = (A.t * Bv.z) + (B.t * Av.z)
            d2 = (Av.x * Bv.y) - (Av.y * Bv.x)
            z = parseFloat((d1 + d2).toFixed(5))

            return new Quaternion t, new Vector3 x, y, z

    ###*
        Make rotation quaternion
        @param {number} radian.
        @param {Vector3} vector.
    ###
    makeRotatialQuaternion = (radian, vector) ->
    
        ret = new Quaternion
        ccc = 0
        sss = 0
        axis = new Vector3
        axis.copy vector

        norm = vector.norm()

        return ret if norm <= 0.0

        axis.normalize()

        ccc = cos(0.5 * radian)
        sss = sin(0.5 * radian)

        t = ccc
        axis.multiplyScalar sss

        ret.set t, axis

        return ret


    exports.Object3D = Object3D
    exports.Matrix2  = Matrix2
    exports.Matrix4  = Matrix4
    exports.Camera   = Camera
    exports.Renderer = Renderer
    exports.Texture  = Texture
    exports.Triangle = Triangle
    exports.Scene = Scene
    exports.Line  = Line
    exports.Plate = Plate
    exports.Cube  = Cube
    exports.Face  = Face
    exports.Face2  = Face2
    exports.Particle = Particle
    exports.Texture  = Texture
    exports.Vector3  = Vector3
    exports.Color    = Color
    exports.Quaternion = Quaternion
    exports.AmbientLight = AmbientLight
    exports.DirectionalLight = DirectionalLight
    exports.PointLight = PointLight

    return


do (win = window, doc = window.document, exports = window) ->

    #Import
    {tan, cos, sin, PI} = Math
    {Face2, Object3D, Line, Color, AmbientLight, DirectionalLight, Plate, Face, Cube, Texture, Triangle, Matrix4, Camera, Renderer, Scene, Vector3, Particle} = window.S3D

    $ = (selector) ->
        doc.querySelector selector

    requestAnimFrame = do ->
        return win.requestAnimationFrame or
               win.webkitRequestAnimationFrame or
               win.mozRequestAnimationFrame or
               win.msRequestAnimationFrame or
               (callback) ->
                   setTimeout callback, 16

    DEG_TO_RAD = PI / 180

    isTouch = 'ontouchstart' of window
    MOUSE_DOWN = if isTouch then 'touchstart' else 'mousedown'
    MOUSE_MOVE = if isTouch then 'touchmove' else 'mousemove'
    MOUSE_UP   = if isTouch then 'touchend' else 'mouseup'

    textureImage = null
    logoImage    = null
    photoImage   = null
    rotX = 0
    rotY = 0

    renderer = null
    camera   = null
    scene    = null

    getVideo = ->

        video = doc.getElementById 'video'
        video.autoplay = true
        video.loop = true

        return video


    init = ->

        video = getVideo()

        cv  = doc.getElementById 'canvas'
        ctx = cv.getContext '2d'
        w = cv.width  = win.innerWidth
        h = cv.height = win.innerHeight
        fov = 60
        aspect = w / h


        camera = new Camera 40, aspect, 0.1, 10000
        camera.position.x = 10
        camera.position.y = 20
        camera.position.z = 200
        #camera.up = new Vector3 1, 0, 0
        camera.lookAt new Vector3 0, 50, 0
        camera.lookAtLock = true
        scene    = new Scene
        renderer = new Renderer cv, '#111'
        #renderer.fog      = false
        #renderer.lighting = false
        #renderer.wireframe = true

        create = ->

            onJsdoit = document.domain is 'jsrun.it'

            imgURL          = if not onJsdoit then 'img/aXjiA.png' else 'http://jsrun.it/assets/y/r/A/V/yrAVl.jpg'
            imgHtml5LogoURL = if not onJsdoit then 'img/HTML5_Logo_512.png' else 'http://jsrun.it/assets/z/1/2/9/z129U.png'
            imgPhotoURL     = if not onJsdoit then 'img/photo.jpg' else 'http://jsrun.it/assets/k/M/J/J/kMJJS.png'

            materials1 = [
                imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL,
                imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL, imgPhotoURL
            ]

            materials2 = [
                video, video, video, video, video, video,
                video, video, video, video, video, video
            ]

            materials3 = [
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
                new Color(200, 0, 0, 1)
            ]

            cube1 = new Cube 50, 20, 20, 1, 1, 1, materials2
            cube1.position.z = -50
            cube1.position.y = 50
            cube1.rotation.z = 30
            cube1.scale.set(0.5, 0.5, 0.5)

            cube2 = new Cube 20, 20, 20, 1, 1, 1, materials1
            cube2.position.z = -150
            cube2.position.y = 50
            cube2.position.x = 50

            cube3 = new Cube 20, 20, 20, 1, 1, 1, materials3
            cube3.position.z = -350
            cube3.position.x = 50
            cube3.position.y = 80

            plate1 = new Plate 50, 50, 1, 1, imgHtml5LogoURL, imgHtml5LogoURL
            plate1.position.set -50, 10, -300

            plate2 = new Plate 50, 50, 1, 1, video, video
            plate2.position.set 0, 100, -500

            line1 = new Line(0, 0, -200, 0, 0, 200, new Color(255, 0, 0, 0.3))
            line2 = new Line(-200, 0, 0, 200, 0, 0, new Color(0, 255, 0, 0.3))
            line3 = new Line(0, 200, 0, 0, -200, 0, new Color(0, 0, 255, 0.3))

            particle1 = new Particle(new Vector3(50, 50, 30), 2000)
            particle2 = new Particle(new Vector3(150, 50, 0), 3000)
            particle3 = new Particle(new Vector3(250, 30, -150), 2500)
            particle4 = new Particle(new Vector3(-150, 150, -250), 4000)
            particle5 = new Particle(new Vector3(-250, 250, 50), 3500)

            size = 500
            container = new Object3D
            container.position.x = -(size * 0.5)
            container.position.z = -(size * 0.5)

            for i in [0..(size / 10)]
                z = i * 10
                line = new Line(0, 0, z, size, 0, z, new Color(255, 255, 255, 0.3))
                container.add line

            for i in [0..(size / 10)]
                x = i * 10
                line = new Line(x, 0, 0, x, 0, size, new Color(255, 255, 255, 0.3))
                container.add line

            ambLight = new AmbientLight(0.1)
            dirLight = new DirectionalLight(1.0, (new Vector3(0, 0, 1)).normalize())
           
            scene.add ambLight
            scene.add dirLight

            scene.add particle1
            scene.add particle2
            scene.add particle3
            scene.add particle4
            scene.add particle5
            scene.add plate1
            scene.add plate2
            scene.add container
            scene.add cube1
            scene.add cube2
            scene.add cube3
            scene.add line1
            scene.add line2
            scene.add line3

            angle = 0

            do _loop = ->
                angle = (++angle % 360)
                plate1.rotation.z = angle
                plate2.rotation.x = angle * 3
                cube1.rotation.z = angle
                cube2.rotation.x = angle * 2
                cube3.rotation.x = angle * 3
                cube3.rotation.y = angle * 3
                cube3.rotation.z = angle * 3

                s = 1 + sin(angle * DEG_TO_RAD)
                cube3.scale.set(s, s, s)

                renderer.render scene, camera
                requestAnimFrame _loop

        create()

        dragging = false
        prevX = 0
        prevY = 0

        # Events
        win.addEventListener 'mousewheel', (e) ->
            camera.position.z += (e.wheelDelta / 10)
            renderer.render scene, camera
            e.preventDefault()
        , false

        base = 100
        startZoom = 0
        document.addEventListener 'gesturechange', (e) ->
            num =  e.scale * base - base
            camera.position.z = startZoom - num
            renderer.render scene, camera
            e.preventDefault()
        , false
        
        document.addEventListener 'gesturestart', ->
            startZoom = camera.position.z
        , false

        doc.addEventListener 'touchstart', (e) ->
            e.preventDefault()
        , false

        doc.addEventListener MOUSE_DOWN, (e) ->
            dragging = true
            prevX = if isTouch then e.touches[0].pageX else e.pageX
            prevY = if isTouch then e.touches[0].pageY else e.pageY
        , false

        moveX = camera.position.x
        moveY = camera.position.y
        doc.addEventListener MOUSE_MOVE, (e) ->
            return if dragging is false

            pageX = if isTouch then e.touches[0].pageX else e.pageX
            pageY = if isTouch then e.touches[0].pageY else e.pageY

            moveX -= (prevX - pageX) * 3
            moveY += (prevY - pageY) * 3

            camera.position.y = moveY
            camera.position.x = moveX

            prevX = pageX
            prevY = pageY
            
            renderer.render scene, camera
        , false

        doc.addEventListener MOUSE_UP, (e) ->
            dragging = false
        , false

        # コントロール
        btnFog   = $('#fog')
        btnLight = $('#light')
        btnWire  = $('#wire')
        fog   = true
        light = true
        wire  = false

        btnFog.addEventListener MOUSE_DOWN, ->
            fog = !fog
            type = if fog then 'ON' else 'OFF'
            btnFog.value = "フォグ[#{type}]"
            renderer.fog = fog
        , false

        btnLight.addEventListener MOUSE_DOWN, ->
            light = !light
            type = if light then 'ON' else 'OFF'
            btnLight.value = "ライティング[#{type}]"
            renderer.lighting = light
        , false

        btnWire.addEventListener MOUSE_DOWN, ->
            wire = !wire
            type = if wire then 'ON' else 'OFF'
            btnWire.value = "ワイヤーフレーム[#{type}]"
            renderer.wireframe = wire
        , false

    doc.addEventListener 'DOMContentLoaded', init, false
