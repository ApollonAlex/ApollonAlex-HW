library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.first_round_pkg.all;

entity first_round is
  port(
    clk        : in  std_logic;
    reset      : in  std_logic;

    plain_text : in  std_logic_vector(63 downto 0);
    init_keys  : in  wk_rk_array;

    encrypt_en : in  std_logic;
    r_cnt      : in  unsigned(4 downto 0);

    X_after    : out std_logic_vector(63 downto 0)
  );
end entity first_round;

architecture rtl of first_round is

  -- Signals for keys
  signal wk0, wk1, rk0, rk1 : std_logic_vector(15 downto 0);

  -- Signals for plaintext split
  signal p0, p1, p2, p3 : std_logic_vector(15 downto 0);

  -- Signals for pre-whitening and F outputs
  signal x0_w, x2_w  : std_logic_vector(15 downto 0);
  signal f_x0, f_x2  : std_logic_vector(15 downto 0);
  signal x1_w, x3_w  : std_logic_vector(15 downto 0);

  -- Signals for RP
  signal x_before_rp : std_logic_vector(63 downto 0);
  signal x_after_rp  : std_logic_vector(63 downto 0);

  -- Register for output
  signal x_after_reg : std_logic_vector(63 downto 0);

begin

  --------------------------------------------------------------------------
  -- 1) Unpack keys
  --------------------------------------------------------------------------
  wk0 <= init_keys(0);
  wk1 <= init_keys(1);
  rk0 <= init_keys(2);
  rk1 <= init_keys(3);

  --------------------------------------------------------------------------
  -- 2) Split plaintext into 4x16-bit words
  --------------------------------------------------------------------------
  p0 <= plain_text(63 downto 48);
  p1 <= plain_text(47 downto 32);
  p2 <= plain_text(31 downto 16);
  p3 <= plain_text(15 downto 0);

  --------------------------------------------------------------------------
  -- 3) Pre-whitening on X0 and X2
  --------------------------------------------------------------------------
  x0_w <= p0 xor wk0;
  x2_w <= p2 xor wk1;

  --------------------------------------------------------------------------
  -- 4) Call F functions (direct entity instantiation)
  --------------------------------------------------------------------------
  U_F1 : entity work.function_f_new
    port map(
      data_in  => x0_w,
      data_out => f_x0
    );

  U_F2 : entity work.function_f_new
    port map(
      data_in  => x2_w,
      data_out => f_x2
    );

  --------------------------------------------------------------------------
  -- 5) XOR with F outputs + round keys on X1 and X3
  --------------------------------------------------------------------------
  x1_w <= p1 xor f_x0 xor rk0;
  x3_w <= p3 xor f_x2 xor rk1;

  --------------------------------------------------------------------------
  -- 6) Bundle before RP
  --------------------------------------------------------------------------
  x_before_rp <= x0_w & x1_w & x2_w & x3_w;

  --------------------------------------------------------------------------
  -- 7) Call RP (direct entity instantiation)
  --------------------------------------------------------------------------
  U_RP : entity work.rp
    port map(
      X      => x_before_rp,
      rp_out => x_after_rp
    );

  --------------------------------------------------------------------------
  -- 8) Register output, gated by encrypt_en and r_cnt = 0
  --------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        x_after_reg <= (others => '0');
      elsif (encrypt_en = '1' and r_cnt = 0) then
        x_after_reg <= x_after_rp;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- 9) Output
  --------------------------------------------------------------------------
  X_after <= x_after_reg;

end architecture rtl;
