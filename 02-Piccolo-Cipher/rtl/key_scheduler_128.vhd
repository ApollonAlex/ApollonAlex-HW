library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_scheduler_128 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;

    -- 128-bit key input (loaded beforehand)
    key128   : in  std_logic_vector(127 downto 0);

    -- When asserted, load key128 into internal k0..k7 regs (one-shot)
    load_key : in  std_logic;

    -- From FSM for current round index i:
    ip2_mod8 : in  std_logic_vector(2 downto 0); -- = (i+2) mod 8
    ip3_mod8 : in  std_logic_vector(2 downto 0); -- = (i+3) mod 8

    -- Round constants for i and i+1 (provided by ROM / top level)
    con_i    : in  std_logic_vector(15 downto 0);
    con_ip1  : in  std_logic_vector(15 downto 0);
    encrypt_en : in std_logic;

    -- Whitening keys (stable once key is loaded)
    wk0      : out std_logic_vector(15 downto 0);
    wk1      : out std_logic_vector(15 downto 0);
    wk2      : out std_logic_vector(15 downto 0);
    wk3      : out std_logic_vector(15 downto 0);

    -- Round keys pair
    rk_i     : out std_logic_vector(15 downto 0);
    rk_ip1   : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of key_scheduler_128 is
  -- Internal subkeys (16-bit each)
  signal k0, k1, k2, k3, k4, k5, k6, k7 : std_logic_vector(15 downto 0) := (others => '0');

  -- Selected subkeys for this round
  signal sel_a : std_logic_vector(15 downto 0);  -- k_{(i+2) mod 8} (after perm if applied)
  signal sel_b : std_logic_vector(15 downto 0);  -- k_{(i+3) mod 8}
begin

  ------------------------------------------------------------------------------
  -- Load + optional permutation of (k0..k7)
  -- Permutation is applied when ip2_mod8 = "000"  (i.e., (i+2) mod 8 = 0).
  -- IMPORTANT: FSM must drive ip2_mod8="000" for ONE clock only when permutation
  -- must occur, otherwise permutation repeats every clock while "000".
  ------------------------------------------------------------------------------
  process(clk)
    variable nk0, nk1, nk2, nk3, nk4, nk5, nk6, nk7 : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        k0 <= (others => '0'); k1 <= (others => '0'); k2 <= (others => '0'); k3 <= (others => '0');
        k4 <= (others => '0'); k5 <= (others => '0'); k6 <= (others => '0'); k7 <= (others => '0');

      else
        if load_key = '1' then
          -- Load initial key words
          k0 <= key128(127 downto 112);
          k1 <= key128(111 downto 96);
          k2 <= key128(95  downto 80);
          k3 <= key128(79  downto 64);
          k4 <= key128(63  downto 48);
          k5 <= key128(47  downto 32);
          k6 <= key128(31  downto 16);
          k7 <= key128(15  downto 0);

        elsif (ip2_mod8 = "110" and encrypt_en='1') then
          -- Apply permutation:
          -- (k0,k1,k2,k3,k4,k5,k6,k7) <- (k2,k1,k6,k7,k0,k3,k4,k5)
          if decrypt='0' then
    -- forward
             nk0 := k2; nk1 := k1; nk2 := k6; nk3 := k7;
             nk4 := k0; nk5 := k3; nk6 := k4; nk7 := k5;
          else
    -- inverse
             nk0 := k4; nk1 := k1; nk2 := k0; nk3 := k5;
             nk4 := k6; nk5 := k7; nk6 := k2; nk7 := k3;
          end if;

             k0<=nk0; k1<=nk1; k2<=nk2; k3<=nk3;
             k4<=nk4; k5<=nk5; k6<=nk6; k7<=nk7;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Whitening keys:
  -- wk0 <- k0^L | k3^R
  -- wk1 <- k1^L | k0^R
  -- wk2 <- k4^L | k7^R
  -- wk3 <- k7^L | k4^R
  ------------------------------------------------------------------------------
  wk0 <= k0(15 downto 8) & k1(7 downto 0);
  wk1 <= k1(15 downto 8) & k0(7 downto 0);
  wk2 <= k4(15 downto 8) & k7(7 downto 0);
  wk3 <= k7(15 downto 8) & k4(7 downto 0);

  ------------------------------------------------------------------------------
  -- Select k_{(i+2) mod 8} and k_{(i+3) mod 8} based on FSM inputs
  -- (VHDL-93/2002 friendly: explicit sensitivity list)
  ------------------------------------------------------------------------------
  process(ip2_mod8, ip3_mod8, k0, k1, k2, k3, k4, k5, k6, k7)
  begin
    -- Defaults to avoid latches
    sel_a <= k0;
    sel_b <= k0;

    case ip2_mod8 is
      when "000" => sel_a <= k0;
      when "001" => sel_a <= k1;
      when "010" => sel_a <= k2;
      when "011" => sel_a <= k3;
      when "100" => sel_a <= k4;
      when "101" => sel_a <= k5;
      when "110" => sel_a <= k6;
      when "111" => sel_a <= k7;
      when others => sel_a <= k0;
    end case;

    case ip3_mod8 is
      when "000" => sel_b <= k0;
      when "001" => sel_b <= k1;
      when "010" => sel_b <= k2;
      when "011" => sel_b <= k3;
      when "100" => sel_b <= k4;
      when "101" => sel_b <= k5;
      when "110" => sel_b <= k6;
      when "111" => sel_b <= k7;
      when others => sel_b <= k0;
    end case;
  end process;

  ------------------------------------------------------------------------------
  -- Round keys pair:
  --   rk_i   = k_{(i+2) mod 8} XOR con_i
  --   rk_i+1 = k_{(i+3) mod 8} XOR con_{i+1}
  ------------------------------------------------------------------------------
  rk_i   <= sel_a xor con_i;
  rk_ip1 <= sel_b xor con_ip1;

end architecture;

